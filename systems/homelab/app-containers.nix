{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    concatLines
    concatStringsSep
    filterAttrs
    flatten
    listToAttrs
    mapAttrs'
    mapAttrsToList
    mkEnableOption
    mkIf
    mkOption
    nameValuePair
    optionalString
    types
    unique
    ;

  cfg = config.homelab;
  enabledApps = filterAttrs (_: app: app.enable) cfg.apps;
  hasApps = enabledApps != { };
  cloudflareTunnelId = "a19003a7-293f-4872-b8a5-1db544878f45";

  validId = value: builtins.match "^[a-z0-9][a-z0-9-]*$" value != null;

  portMapFor =
    services: base:
    let
      names = builtins.attrNames services;
    in
    listToAttrs (
      builtins.genList (
        index:
        let
          serviceName = builtins.elemAt names index;
        in
        nameValuePair serviceName (base + index)
      ) (builtins.length names)
    );

  unitPrefixFor = app: "${app.contract.name}-${app.contract.channel}";

  caddyPortFor =
    app: if app.host.caddyPort == null then app.host.loopbackPortBase - 1 else app.host.caddyPort;

  servicePortClaimsForApp =
    app:
    let
      servicePorts = portMapFor app.contract.services app.host.loopbackPortBase;
    in
    builtins.attrValues servicePorts;

  registryAuthFileFor =
    app:
    if app.host.registryAuth == null then null else cfg.registryAuths.${app.host.registryAuth}.authFile;

  imageRefFor =
    app: service:
    if builtins.hasAttr service.image app.contract.images then
      app.contract.images.${service.image}
    else
      "invalid-image-reference";

  envTemplateNameFor = app: serviceName: "${unitPrefixFor app}-${serviceName}.env";

  serviceEnvContent =
    app: service:
    let
      secretLine =
        envName:
        let
          secretName = builtins.getAttr envName app.host.secretMap;
        in
        "${envName}=${builtins.getAttr secretName config.sops.placeholder}";

      envLines = mapAttrsToList (key: value: "${key}=${value}") service.env;
      secretLines = map secretLine service.requiredSecretEnv;
    in
    concatStringsSep "\n" (envLines ++ secretLines) + "\n";

  appSecretNames =
    app:
    unique (
      flatten (
        mapAttrsToList (
          _serviceName: service:
          map (
            envName:
            if builtins.hasAttr envName app.host.secretMap then
              builtins.getAttr envName app.host.secretMap
            else
              null
          ) service.requiredSecretEnv
        ) app.contract.services
      )
    );

  secretNames = builtins.filter (name: name != null) (
    unique (flatten (mapAttrsToList (_appName: app: appSecretNames app) enabledApps))
  );

  sopsSecrets = listToAttrs (
    map (secretName: nameValuePair secretName { mode = "0400"; }) secretNames
  );

  sopsTemplates = listToAttrs (
    flatten (
      mapAttrsToList (
        _appName: app:
        mapAttrsToList (
          serviceName: service:
          nameValuePair (envTemplateNameFor app serviceName) {
            content = serviceEnvContent app service;
            mode = "0400";
            owner = "root";
          }
        ) app.contract.services
      ) enabledApps
    )
  );

  appIngress = listToAttrs (
    mapAttrsToList (
      _appName: app: nameValuePair app.host.domain "http://localhost:${toString (caddyPortFor app)}"
    ) enabledApps
  );

  routeLineFor =
    app: servicePorts: route:
    let
      targetPort =
        if builtins.hasAttr route.service servicePorts then servicePorts.${route.service} else 0;
      target = "127.0.0.1:${toString targetPort}";
    in
    if route.path == "/" then "reverse_proxy ${target}" else "reverse_proxy ${route.path} ${target}";

  caddyVirtualHosts = mapAttrs' (
    _appName: app:
    let
      servicePorts = portMapFor app.contract.services app.host.loopbackPortBase;
      caddyPort = caddyPortFor app;
    in
    nameValuePair "http://${app.host.domain}:${toString caddyPort}" {
      extraConfig = ''
        bind 127.0.0.1

        ${concatLines (map (routeLineFor app servicePorts) app.contract.routes)}
      '';
    }
  ) enabledApps;

  imageUnitFor =
    app: serviceName: service:
    let
      authFile = registryAuthFileFor app;
      unitPrefix = unitPrefixFor app;
    in
    nameValuePair "containers/systemd/${unitPrefix}-${serviceName}.image" {
      text = ''
        [Unit]
        Description=Pull ${unitPrefix}-${serviceName} image
        ${optionalString (authFile != null) "Requires=sops-install-secrets.service"}
        After=network-online.target${optionalString (authFile != null) " sops-install-secrets.service"}
        Wants=network-online.target

        [Image]
        Image=${imageRefFor app service}
        ${optionalString (authFile != null) "AuthFile=${authFile}"}
      '';
    };

  volumeUnitFor =
    app: volumeName: _volume:
    let
      unitPrefix = unitPrefixFor app;
    in
    nameValuePair "containers/systemd/${unitPrefix}-${volumeName}.volume" {
      text = ''
        [Volume]
        VolumeName=${unitPrefix}-${volumeName}
      '';
    };

  mountLineFor =
    app: mount:
    "${unitPrefixFor app}-${mount.volume}.volume:${mount.mountPath}${optionalString mount.readOnly ":ro"}";

  containerUnitFor =
    app: serviceName: service:
    let
      unitPrefix = unitPrefixFor app;
      servicePorts = portMapFor app.contract.services app.host.loopbackPortBase;
      authFile = registryAuthFileFor app;
      envTemplate = config.sops.templates.${envTemplateNameFor app serviceName}.path;
      networkService = "${unitPrefix}-network.service";
      volumeServices = map (mount: "${unitPrefix}-${mount.volume}-volume.service") service.volumeMounts;
      volumeLines = map (mount: "Volume=${mountLineFor app mount}") service.volumeMounts;
    in
    nameValuePair "containers/systemd/${unitPrefix}-${serviceName}.container" {
      text = ''
        [Unit]
        Description=${app.contract.name} ${app.contract.channel} ${serviceName} container
        Requires=sops-install-secrets.service ${networkService} ${unitPrefix}-${serviceName}-image.service${
          optionalString (volumeServices != [ ]) " ${concatStringsSep " " volumeServices}"
        }
        After=sops-install-secrets.service network-online.target ${networkService} ${unitPrefix}-${serviceName}-image.service${
          optionalString (volumeServices != [ ]) " ${concatStringsSep " " volumeServices}"
        }
        Wants=network-online.target

        [Container]
        ContainerName=${unitPrefix}-${serviceName}
        Image=${imageRefFor app service}
        Pull=never
        ${optionalString (service.updatePolicy == "registry-auto") "AutoUpdate=registry"}
        ${optionalString (
          service.updatePolicy == "registry-auto" && authFile != null
        ) "Label=io.containers.autoupdate.authfile=${authFile}"}
        LogDriver=journald
        EnvironmentFile=${envTemplate}
        Network=${unitPrefix}.network
        PublishPort=127.0.0.1:${toString servicePorts.${serviceName}}:${toString service.internalPort}
        ${concatLines volumeLines}

        [Service]
        Restart=on-failure
        RestartSec=5s
        TimeoutStartSec=${app.host.timeoutStartSec}
        TimeoutStopSec=120

        [Install]
        WantedBy=multi-user.target
      '';
    };

  networkUnitFor =
    app:
    let
      unitPrefix = unitPrefixFor app;
    in
    nameValuePair "containers/systemd/${unitPrefix}.network" {
      text = ''
        [Network]
        NetworkName=${unitPrefix}
      '';
    };

  appEtc =
    app:
    [
      (networkUnitFor app)
    ]
    ++ mapAttrsToList (volumeUnitFor app) app.contract.volumes
    ++ mapAttrsToList (imageUnitFor app) app.contract.services
    ++ mapAttrsToList (containerUnitFor app) app.contract.services;

  etcEntries = listToAttrs (flatten (mapAttrsToList (_appName: app: appEtc app) enabledApps));

  appServiceNames =
    app:
    let
      unitPrefix = unitPrefixFor app;
    in
    map (serviceName: "${unitPrefix}-${serviceName}.service") (
      builtins.attrNames app.contract.services
    );

  activationApps = mapAttrsToList (
    _appName: app:
    let
      unitPrefix = unitPrefixFor app;
      services = concatStringsSep " " (appServiceNames app);
    in
    ''
      app_prefix=${unitPrefix}
      state_dir=/var/lib/homelab-app-containers
      marker=$state_dir/$app_prefix.sha256

      if ${pkgs.coreutils}/bin/ls /etc/containers/systemd/$app_prefix* >/dev/null 2>&1; then
        mkdir -p "$state_dir"
        new_hash="$(
          for file in /etc/containers/systemd/$app_prefix*; do
            [ -e "$file" ] && ${pkgs.coreutils}/bin/sha256sum "$file"
          done | ${pkgs.coreutils}/bin/sha256sum | ${pkgs.coreutils}/bin/cut -d ' ' -f1
        )"
        old_hash="$(${pkgs.coreutils}/bin/cat "$marker" 2>/dev/null || true)"

        if [ "$new_hash" != "$old_hash" ]; then
          ${pkgs.systemd}/bin/systemctl daemon-reload || true
          ok=1
          for service in ${services}; do
            if ${pkgs.systemd}/bin/systemctl is-active --quiet "$service"; then
              ${pkgs.systemd}/bin/systemctl restart "$service" || ok=0
            else
              ${pkgs.systemd}/bin/systemctl start "$service" || ok=0
            fi
          done

          if [ "$ok" = 1 ]; then
            printf '%s\n' "$new_hash" > "$marker"
          else
            echo "warning: failed to start or restart services for $app_prefix" >&2
          fi
        fi
      fi
    ''
  ) enabledApps;

  assertionsForApp =
    appName: app:
    let
      contract = app.contract;
      routeDomains = map (route: route.host) contract.routes;
      serviceNames = builtins.attrNames contract.services;
      imageNames = builtins.attrNames contract.images;
      volumeNames = builtins.attrNames contract.volumes;
      hostVolumeNames = builtins.attrNames app.host.volumes;
      migrationMode = contract.migrations.mode;
      migrationService = contract.migrations.service;
      registryAutoServices = filterAttrs (
        _: service: service.updatePolicy == "registry-auto"
      ) contract.services;
      migrationServiceIsRegistryAuto =
        migrationService != null && builtins.hasAttr migrationService registryAutoServices;
    in
    [
      {
        assertion = validId contract.name;
        message = "homelab.apps.${appName}: contract.name must match ^[a-z0-9][a-z0-9-]*$.";
      }
      {
        assertion = validId contract.channel;
        message = "homelab.apps.${appName}: contract.channel must match ^[a-z0-9][a-z0-9-]*$.";
      }
      {
        assertion = app.host.domain != null;
        message = "homelab.apps.${appName}: host.domain is required.";
      }
      {
        assertion = app.host.loopbackPortBase > 1024;
        message = "homelab.apps.${appName}: host.loopbackPortBase must be greater than 1024.";
      }
      {
        assertion = builtins.all (domain: domain == app.host.domain) routeDomains;
        message = "homelab.apps.${appName}: every contract route host must match host.domain.";
      }
      {
        assertion =
          app.host.registryAuth == null || builtins.hasAttr app.host.registryAuth cfg.registryAuths;
        message = "homelab.apps.${appName}: host.registryAuth must reference homelab.registryAuths.";
      }
      {
        assertion =
          migrationMode == "none"
          || (migrationService != null && builtins.elem migrationService serviceNames);
        message = "homelab.apps.${appName}: migrations.service must reference a contract service when migrations are enabled.";
      }
      {
        assertion = migrationMode == "none" || contract.migrations.command != [ ];
        message = "homelab.apps.${appName}: migrations.command is required when migrations are enabled.";
      }
      {
        assertion = migrationMode == "none" || !migrationServiceIsRegistryAuto;
        message = "homelab.apps.${appName}: registry-auto is not allowed on the migration service.";
      }
    ]
    ++ map (route: {
      assertion = builtins.elem route.service serviceNames;
      message = "homelab.apps.${appName}: route ${route.path} must reference contract.services.";
    }) contract.routes
    ++ flatten (
      mapAttrsToList (
        serviceName: service:
        [
          {
            assertion = builtins.elem service.image imageNames;
            message = "homelab.apps.${appName}.${serviceName}: service.image must reference contract.images.";
          }
        ]
        ++ map (envName: {
          assertion = builtins.hasAttr envName app.host.secretMap;
          message = "homelab.apps.${appName}.${serviceName}: requiredSecretEnv ${envName} is missing from host.secretMap.";
        }) service.requiredSecretEnv
        ++ map (mount: {
          assertion = builtins.elem mount.volume volumeNames && builtins.elem mount.volume hostVolumeNames;
          message = "homelab.apps.${appName}.${serviceName}: volumeMount ${mount.volume} must exist in contract.volumes and host.volumes.";
        }) service.volumeMounts
      ) contract.services
    );

  domainList = mapAttrsToList (_appName: app: app.host.domain) enabledApps;
  caddyPorts = mapAttrsToList (_appName: app: caddyPortFor app) enabledApps;
  serviceLoopbackPorts = flatten (
    mapAttrsToList (_appName: app: servicePortClaimsForApp app) enabledApps
  );
in
{
  options.homelab = {
    registryAuths = mkOption {
      type = types.attrsOf (
        types.submodule {
          options.authFile = mkOption {
            type = types.str;
            description = "Runtime path to a Podman auth.json file.";
          };
        }
      );
      default = { };
      description = "Named registry auth files available to homelab app containers.";
    };

    apps = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            enable = mkEnableOption "homelab app container admission";

            contract = mkOption {
              type = types.submodule {
                options = {
                  name = mkOption { type = types.str; };
                  channel = mkOption { type = types.str; };
                  images = mkOption { type = types.attrsOf types.str; };
                  services = mkOption {
                    type = types.attrsOf (
                      types.submodule {
                        options = {
                          image = mkOption { type = types.str; };
                          internalPort = mkOption { type = types.port; };
                          healthPath = mkOption {
                            type = types.nullOr types.str;
                            default = null;
                          };
                          env = mkOption {
                            type = types.attrsOf types.str;
                            default = { };
                          };
                          requiredSecretEnv = mkOption {
                            type = types.listOf types.str;
                            default = [ ];
                          };
                          updatePolicy = mkOption {
                            type = types.enum [
                              "manual"
                              "registry-auto"
                              "pinned-digest"
                            ];
                          };
                          volumeMounts = mkOption {
                            type = types.listOf (
                              types.submodule {
                                options = {
                                  volume = mkOption { type = types.str; };
                                  mountPath = mkOption { type = types.str; };
                                  readOnly = mkOption {
                                    type = types.bool;
                                    default = false;
                                  };
                                };
                              }
                            );
                            default = [ ];
                          };
                        };
                      }
                    );
                  };
                  routes = mkOption {
                    type = types.listOf (
                      types.submodule {
                        options = {
                          host = mkOption { type = types.str; };
                          path = mkOption { type = types.str; };
                          service = mkOption { type = types.str; };
                        };
                      }
                    );
                  };
                  migrations = mkOption {
                    type = types.submodule {
                      options = {
                        mode = mkOption {
                          type = types.enum [
                            "none"
                            "manual"
                          ];
                          default = "none";
                        };
                        service = mkOption {
                          type = types.nullOr types.str;
                          default = null;
                        };
                        command = mkOption {
                          type = types.listOf types.str;
                          default = [ ];
                        };
                      };
                    };
                    default = { };
                  };
                  volumes = mkOption {
                    type = types.attrsOf (
                      types.submodule {
                        options.notes = mkOption {
                          type = types.str;
                          default = "";
                        };
                      }
                    );
                    default = { };
                  };
                  notes = mkOption {
                    type = types.str;
                    default = "";
                  };
                };
              };
            };

            host = {
              domain = mkOption {
                type = types.nullOr types.str;
                default = null;
              };
              loopbackPortBase = mkOption {
                type = types.port;
                description = "First host loopback port assigned to app service containers.";
              };
              caddyPort = mkOption {
                type = types.nullOr types.port;
                default = null;
              };
              registryAuth = mkOption {
                type = types.nullOr types.str;
                default = null;
              };
              timeoutStartSec = mkOption {
                type = types.str;
                default = "300";
              };
              secretMap = mkOption {
                type = types.attrsOf types.str;
                default = { };
              };
              volumes = mkOption {
                type = types.attrsOf (
                  types.submodule {
                    options = {
                      backup = mkOption {
                        type = types.bool;
                        default = false;
                      };
                      class = mkOption {
                        type = types.str;
                        default = "local-podman";
                      };
                    };
                  }
                );
                default = { };
              };
            };
          };
        }
      );
      default = { };
      description = "Admitted homelab apps rendered from app-owned runtime contracts.";
    };
  };

  config = mkIf hasApps {
    assertions = [
      {
        assertion = config.virtualisation.podman.enable;
        message = "homelab.apps requires virtualisation.podman.enable.";
      }
      {
        assertion = unique domainList == domainList;
        message = "homelab.apps entries must use unique host.domain values.";
      }
      {
        assertion =
          unique serviceLoopbackPorts == serviceLoopbackPorts
          && builtins.all (port: !(builtins.elem port caddyPorts)) serviceLoopbackPorts;
        message = "homelab.apps entries must use unique service loopback ports, and service ports must not collide with host.caddyPort.";
      }
    ]
    ++ flatten (mapAttrsToList assertionsForApp enabledApps);

    sops.secrets = sopsSecrets;
    sops.templates = sopsTemplates;

    services.caddy = {
      enable = true;
      virtualHosts = caddyVirtualHosts;
    };

    services.cloudflared.tunnels.${cloudflareTunnelId}.ingress = appIngress;

    environment.etc = etcEntries;

    system.activationScripts.homelabAppContainersRefresh = {
      deps = [
        "etc"
        "specialfs"
      ];
      text = concatLines activationApps;
    };
  };
}
