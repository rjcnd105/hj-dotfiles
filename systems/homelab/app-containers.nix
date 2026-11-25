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
    mapAttrsToList
    mkEnableOption
    mkIf
    mkOption
    nameValuePair
    optionalString
    types
    unique
    ;

  conventions = import ./app-conventions.nix { inherit lib; };
  inherit (conventions)
    appGatewayFor
    appSubnetFor
    bridgeInterfaceFor
    sharedPostgresNameFor
    unitPrefixFor
    usesSharedOllama
    usesSharedPostgres
    ;

  cfg = config.homelab;
  enabledApps = filterAttrs (_: app: app.enable) cfg.apps;
  hasApps = enabledApps != { };
  podmanDnsLifecycleService = cfg.podmanDnsLifecycle.unit;

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

  servicePortClaimsForApp =
    app: builtins.attrValues (portMapFor app.contract.services app.host.loopbackPortBase);

  imageRefFor = app: service: app.contract.images.${service.image};

  envTemplateNameFor = app: serviceName: "${unitPrefixFor app}-${serviceName}.env";

  releaseChannelFor =
    app:
    if builtins.hasAttr app.contract.channel app.contract.release.channels then
      app.contract.release.channels.${app.contract.channel}
    else
      null;

  releaseImageNameFor =
    app: service:
    let
      imageRef = imageRefFor app service;
      releaseChannel = releaseChannelFor app;
    in
    if releaseChannel == null then imageRef else lib.removeSuffix ":${releaseChannel.tag}" imageRef;

  smokePathsFor =
    app:
    let
      releaseChannel = releaseChannelFor app;
      serviceHealthPaths = builtins.filter (path: path != null) (
        mapAttrsToList (_serviceName: service: service.healthPath) app.contract.services
      );
    in
    if releaseChannel != null && releaseChannel.smokePaths != [ ] then
      releaseChannel.smokePaths
    else if serviceHealthPaths != [ ] then
      unique serviceHealthPaths
    else
      [ "/" ];

  serviceEnvContent =
    app: service:
    let
      secretLine =
        envName:
        let
          secretName = builtins.getAttr envName app.host.secretMap;
        in
        "${envName}=${builtins.getAttr secretName config.sops.placeholder}";

      effectiveEnv = {
        PORT = toString service.internalPort;
      }
      // service.env;
      envLines = mapAttrsToList (key: value: "${key}=${value}") effectiveEnv;
      secretLines = map secretLine service.requiredSecretEnv;
      platformLines =
        lib.optional (usesSharedPostgres app) (
          "DATABASE_URL=postgresql://${sharedPostgresNameFor app}:"
          + builtins.getAttr app.host.postgresPasswordSecret config.sops.placeholder
          + "@${appGatewayFor app}:5432/${sharedPostgresNameFor app}"
        )
        ++ lib.optional (usesSharedOllama app) (
          "OLLAMA_URL=http://${appGatewayFor app}:${toString config.services.ollama.port}"
        );
    in
    concatStringsSep "\n" (envLines ++ secretLines ++ platformLines) + "\n";

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
    unique (
      flatten (mapAttrsToList (_appName: app: appSecretNames app) enabledApps)
      ++ mapAttrsToList (
        _appName: app: if usesSharedPostgres app then app.host.postgresPasswordSecret else null
      ) enabledApps
    )
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

  routeLineFor =
    servicePorts: route:
    let
      target = "127.0.0.1:${toString servicePorts.${route.service}}";
    in
    if route.path == "/" then "reverse_proxy ${target}" else "reverse_proxy ${route.path} ${target}";

  appPublicRoutes = listToAttrs (
    mapAttrsToList (
      _appName: app:
      let
        servicePorts = portMapFor app.contract.services app.host.loopbackPortBase;
      in
      nameValuePair app.host.domain {
        extraConfig = concatLines (map (routeLineFor servicePorts) app.contract.routes);
      }
    ) enabledApps
  );

  quadletVolumeFor =
    app: volumeName: _volume:
    let
      unitPrefix = unitPrefixFor app;
    in
    nameValuePair "${unitPrefix}-${volumeName}" {
      autoStart = false;
      volumeConfig.name = "${unitPrefix}-${volumeName}";
    };

  mountLineFor =
    app: mount:
    "${unitPrefixFor app}-${mount.volume}.volume:${mount.mountPath}${optionalString mount.readOnly ":ro"}";

  podmanMountLineFor =
    app: mount:
    "${unitPrefixFor app}-${mount.volume}:${mount.mountPath}${optionalString mount.readOnly ":ro"}";

  quadletContainerFor =
    app: serviceName: service:
    let
      unitPrefix = unitPrefixFor app;
      servicePorts = portMapFor app.contract.services app.host.loopbackPortBase;
      envTemplate = config.sops.templates.${envTemplateNameFor app serviceName}.path;
      networkService = "${unitPrefix}-network.service";
      dependencyServices = map (name: "${unitPrefix}-${name}.service") service.dependsOn;
      volumes = map (mount: mountLineFor app mount) service.volumeMounts;
    in
    nameValuePair "${unitPrefix}-${serviceName}" {
      unitConfig = {
        Description = "${app.contract.name} ${app.contract.channel} ${serviceName} container";
        Requires = [
          "sops-install-secrets.service"
          podmanDnsLifecycleService
        ]
        ++ dependencyServices
        ++ lib.optional (usesSharedPostgres app) "postgresql.service";
        Wants = lib.optional (usesSharedPostgres app) "homelab-postgres-credentials.service";
        After = [
          "sops-install-secrets.service"
          podmanDnsLifecycleService
        ]
        ++ dependencyServices
        ++ lib.optionals (usesSharedPostgres app) [
          "postgresql.service"
          "homelab-postgres-credentials.service"
        ];
        PartOf = [
          networkService
          podmanDnsLifecycleService
        ];
      };
      containerConfig = {
        name = "${unitPrefix}-${serviceName}";
        image = imageRefFor app service;
        pull = "never";
        logDriver = "journald";
        environmentFiles = [ envTemplate ];
        networks = [ "${unitPrefix}.network" ];
        networkAliases = [ "${unitPrefix}-${serviceName}" ];
        publishPorts = [
          "127.0.0.1:${toString servicePorts.${serviceName}}:${toString service.internalPort}"
        ];
        inherit volumes;
      }
      // lib.optionalAttrs (service.readiness != null) {
        healthCmd = lib.escapeShellArgs service.readiness.command;
        healthInterval = service.readiness.interval;
        healthRetries = service.readiness.retries;
        healthTimeout = service.readiness.timeout;
        notify = "healthy";
      };
      serviceConfig = {
        Restart = "on-failure";
        RestartSec = "5s";
        TimeoutStartSec = app.host.timeoutStartSec;
        TimeoutStopSec = 120;
        # -current 태그는 appctl이 첫 배포에서 만드는 활성화 포인터다. 그 전에 시작하면
        # pull=never라 실패해 switch가 status 4로 끝나므로 태그가 없으면 실패 없이 건너뛴다.
        ExecCondition = "${pkgs.podman}/bin/podman image exists ${imageRefFor app service}";
      };
    };

  quadletNetworkFor =
    app:
    let
      unitPrefix = unitPrefixFor app;
    in
    nameValuePair unitPrefix {
      autoStart = false;
      unitConfig = {
        Requires = [ podmanDnsLifecycleService ];
        After = [ podmanDnsLifecycleService ];
        PartOf = [ podmanDnsLifecycleService ];
      };
      networkConfig = {
        name = unitPrefix;
        interfaceName = bridgeInterfaceFor app;
        subnets = [ (appSubnetFor app) ];
        gateways = [ (appGatewayFor app) ];
      };
    };

  migrationServiceFor =
    _appName: app:
    let
      contract = app.contract;
      migrationServiceName = contract.migrations.service;
      unitPrefix = unitPrefixFor app;
      service = contract.services.${migrationServiceName};
      envTemplate = config.sops.templates.${envTemplateNameFor app migrationServiceName}.path;
      imageRef = imageRefFor app service;
      migrateImageFile = "/run/homelab-appctl/${unitPrefix}-migrate.image";
      networkService = "${unitPrefix}-network.service";
      dependencyServices = map (name: "${unitPrefix}-${name}.service") service.dependsOn;
      volumeServices = map (mount: "${unitPrefix}-${mount.volume}-volume.service") service.volumeMounts;
      volumeArgs = concatStringsSep " " (
        map (mount: "--volume ${lib.escapeShellArg (podmanMountLineFor app mount)}") service.volumeMounts
      );
    in
    nameValuePair "${unitPrefix}-migrate" {
      description = "Run ${contract.name} ${contract.channel} manual migration";
      requires = [
        "sops-install-secrets.service"
        "network-online.target"
        networkService
      ]
      ++ dependencyServices
      ++ volumeServices
      ++ lib.optional (usesSharedPostgres app) "postgresql.service";
      wants = lib.optional (usesSharedPostgres app) "homelab-postgres-credentials.service";
      after = [
        "sops-install-secrets.service"
        "network-online.target"
        networkService
      ]
      ++ dependencyServices
      ++ volumeServices
      ++ lib.optionals (usesSharedPostgres app) [
        "postgresql.service"
        "homelab-postgres-credentials.service"
      ];
      serviceConfig.Type = "oneshot";
      script = ''
        image=${lib.escapeShellArg imageRef}
        if [ -r ${lib.escapeShellArg migrateImageFile} ]; then
          image=$(cat ${lib.escapeShellArg migrateImageFile})
        fi
        ${pkgs.podman}/bin/podman rm -f ${lib.escapeShellArg "${unitPrefix}-migrate"} >/dev/null 2>&1 || true
        exec ${pkgs.podman}/bin/podman run --rm --pull=never --name ${lib.escapeShellArg "${unitPrefix}-migrate"} --env-file ${lib.escapeShellArg envTemplate} --network ${lib.escapeShellArg unitPrefix} ${volumeArgs} "$image" ${lib.escapeShellArgs contract.migrations.command}
      '';
    };

  migrationServices = listToAttrs (
    mapAttrsToList migrationServiceFor (
      filterAttrs (_appName: app: app.contract.migrations.mode == "manual") enabledApps
    )
  );

  serviceMetadataFor =
    app: serviceName: service:
    let
      unitPrefix = unitPrefixFor app;
    in
    {
      name = serviceName;
      imageKey = service.image;
      imageRef = imageRefFor app service;
      imageName = releaseImageNameFor app service;
      serviceUnit = "${unitPrefix}-${serviceName}.service";
      containerName = "${unitPrefix}-${serviceName}";
    };

  appMetadataFor =
    app:
    let
      releaseChannel = releaseChannelFor app;
      unitPrefix = unitPrefixFor app;
    in
    {
      name = app.contract.name;
      channel = app.contract.channel;
      unitPrefix = unitPrefix;
      domain = app.host.domain;
      caddyUrl = "http://127.0.0.1:${toString cfg.caddyPort}";
      contractVersion = 2;
      smokePaths = smokePathsFor app;
      services = mapAttrsToList (serviceMetadataFor app) app.contract.services;
      migration =
        if app.contract.migrations.mode == "manual" then
          {
            mode = "manual";
            service = app.contract.migrations.service;
            unit = "${unitPrefix}-migrate.service";
            command = app.contract.migrations.command;
          }
        else
          {
            mode = "none";
            service = null;
            unit = null;
            command = [ ];
          };
      release =
        if releaseChannel == null then
          null
        else
          {
            manifestUrl = app.contract.release.manifestUrl;
            tag = releaseChannel.tag;
            targetPattern = releaseChannel.targetPattern;
            smokePaths = releaseChannel.smokePaths;
          };
    };

  metadataEtcFor =
    _appName: app:
    nameValuePair "homelab-apps/${app.contract.name}/${app.contract.channel}.json" {
      text = builtins.toJSON (appMetadataFor app) + "\n";
    };

  metadataEtcEntries = listToAttrs (mapAttrsToList metadataEtcFor enabledApps);
  quadletNetworks = listToAttrs (mapAttrsToList (_appName: app: quadletNetworkFor app) enabledApps);
  quadletVolumes = listToAttrs (
    flatten (
      mapAttrsToList (
        _appName: app: mapAttrsToList (quadletVolumeFor app) app.contract.volumes
      ) enabledApps
    )
  );
  quadletContainers = listToAttrs (
    flatten (
      mapAttrsToList (
        _appName: app: mapAttrsToList (quadletContainerFor app) app.contract.services
      ) enabledApps
    )
  );
  homelabAppctl = pkgs.callPackage ../../packages/homelab-appctl/package.nix {
    githubTokenFile = cfg.githubTokenFile;
  };

  assertionsForApp =
    appName: app:
    let
      contract = app.contract;
      routeDomains = map (route: route.host) contract.routes;
      serviceNames = builtins.attrNames contract.services;
      volumeNames = builtins.attrNames contract.volumes;
      hostVolumeNames = builtins.attrNames app.host.volumes;
      releaseChannels = contract.release.channels;
      migrationMode = contract.migrations.mode;
      migrationService = contract.migrations.service;
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
        assertion = builtins.stringLength (bridgeInterfaceFor app) <= 15;
        message = "homelab.apps.${appName}: generated bridge interface must not exceed Linux's 15-character limit.";
      }
      {
        assertion = contract.routes != [ ] && builtins.all (domain: domain == app.host.domain) routeDomains;
        message = "homelab.apps.${appName}: contract.routes must be non-empty and every route host must match host.domain.";
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
        assertion = app.host.subnetId != null;
        message = "homelab.apps.${appName}: host.subnetId is required (bridge subnet 10.90.<id>.0/24).";
      }
      {
        assertion = !usesSharedPostgres app || app.host.postgresPasswordSecret != null;
        message = "homelab.apps.${appName}: needs.postgres requires host.postgresPasswordSecret.";
      }
      {
        assertion =
          !usesSharedPostgres app
          || builtins.all (
            service:
            !(builtins.hasAttr "DATABASE_URL" service.env)
            && !(builtins.elem "DATABASE_URL" service.requiredSecretEnv)
          ) (builtins.attrValues contract.services);
        message = "homelab.apps.${appName}: DATABASE_URL is platform-injected under needs.postgres; the contract must not declare it.";
      }
      {
        assertion =
          !usesSharedOllama app
          || builtins.all (
            service:
            !(builtins.hasAttr "OLLAMA_URL" service.env)
            && !(builtins.elem "OLLAMA_URL" service.requiredSecretEnv)
          ) (builtins.attrValues contract.services);
        message = "homelab.apps.${appName}: OLLAMA_URL is platform-injected under needs.ollama; the contract must not declare it.";
      }
      {
        assertion = releaseChannelFor app != null && contract.release.manifestUrl != null;
        message = "homelab.apps.${appName}: release channel metadata and manifestUrl are required.";
      }
      {
        assertion =
          contract.release.manifestUrl == null || lib.hasInfix "{target}" contract.release.manifestUrl;
        message = "homelab.apps.${appName}: release.manifestUrl must contain the {target} placeholder.";
      }
      {
        assertion =
          contract.release.manifestUrl == null || lib.hasPrefix "https://" contract.release.manifestUrl;
        message = "homelab.apps.${appName}: release.manifestUrl must use HTTPS.";
      }
      {
        assertion = builtins.all (
          origin: lib.hasPrefix "https://" origin && !(lib.hasSuffix "/" origin)
        ) app.host.releaseManifestOrigins;
        message = "homelab.apps.${appName}: host.releaseManifestOrigins must contain HTTPS origins without a trailing slash.";
      }
      {
        assertion = builtins.any (
          origin: lib.hasPrefix "${origin}/" contract.release.manifestUrl
        ) app.host.releaseManifestOrigins;
        message = "homelab.apps.${appName}: release.manifestUrl must match a host-admitted releaseManifestOrigin.";
      }
    ]
    ++ flatten (
      mapAttrsToList (
        channelName: channel:
        [
          {
            assertion = validId channelName;
            message = "homelab.apps.${appName}: release channel ${channelName} must match ^[a-z0-9][a-z0-9-]*$.";
          }
          {
            assertion = lib.hasPrefix "^" channel.targetPattern && lib.hasSuffix "$" channel.targetPattern;
            message = "homelab.apps.${appName}: release channel ${channelName} targetPattern must be anchored with ^ and $.";
          }
        ]
        ++ map (path: {
          assertion = builtins.match "^/.*" path != null;
          message = "homelab.apps.${appName}: release channel ${channelName} smoke path ${path} must start with '/'.";
        }) channel.smokePaths
      ) releaseChannels
    )
    ++ map (route: {
      assertion = builtins.match "^/.*" route.path != null;
      message = "homelab.apps.${appName}: route path ${route.path} must start with '/'.";
    }) contract.routes
    ++ flatten (
      mapAttrsToList (
        serviceName: service:
        [
          {
            assertion = builtins.all (
              dependency: dependency != serviceName && builtins.elem dependency serviceNames
            ) service.dependsOn;
            message = "homelab.apps.${appName}.${serviceName}: dependsOn entries must reference other contract services.";
          }
          {
            assertion = service.readiness == null || service.readiness.command != [ ];
            message = "homelab.apps.${appName}.${serviceName}: readiness.command must not be empty.";
          }
          {
            assertion =
              releaseChannelFor app != null
              && lib.hasSuffix ":${(releaseChannelFor app).tag}" (imageRefFor app service);
            message = "homelab.apps.${appName}.${serviceName}: image refs must end with the admitted release channel tag.";
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
  unitPrefixes = mapAttrsToList (_appName: app: unitPrefixFor app) enabledApps;
  subnetIds = builtins.filter (id: id != null) (
    mapAttrsToList (_appName: app: app.host.subnetId) enabledApps
  );
  serviceLoopbackPorts = flatten (
    mapAttrsToList (_appName: app: servicePortClaimsForApp app) enabledApps
  );
  appDnsFirewallInterfaces = listToAttrs (
    mapAttrsToList (
      _appName: app:
      nameValuePair (bridgeInterfaceFor app) {
        allowedUDPPorts = [ 53 ];
      }
    ) enabledApps
  );
in
{
  options.homelab = {
    githubTokenFile = mkOption {
      type = types.nullOr types.str;
      default = null;
      description = ''
        Runtime path to a file holding a GitHub token used to fetch release
        manifests from private repositories. GitHub's `releases/download` URL
        rejects fine-grained PATs, so appctl resolves the asset through the
        REST API when this is set. Public repositories need no token.
      '';
    };

    apps = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            enable = mkEnableOption "homelab app container admission";

            contract = mkOption {
              type = types.submodule (
                { config, ... }:
                let
                  contractCfg = config;
                in
                {
                  options = {
                    name = mkOption { type = types.str; };
                    channel = mkOption { type = types.str; };
                    schemaVersion = mkOption {
                      type = types.enum [ 2 ];
                      default = 2;
                      description = "Contract schema version (digest-only v2).";
                    };
                    needs = mkOption {
                      type = types.submodule {
                        options.postgres = mkOption {
                          type = types.bool;
                          default = false;
                          description = "Provision a role/database on the shared host PostgreSQL and inject DATABASE_URL.";
                        };
                        options.ollama.models = mkOption {
                          type = types.listOf types.str;
                          default = [ ];
                          description = "Ollama models pulled on the shared host server; a non-empty list injects OLLAMA_URL.";
                        };
                      };
                      default = { };
                    };
                    images = mkOption { type = types.attrsOf types.str; };
                    services = mkOption {
                      type = types.attrsOf (
                        types.submodule {
                          options = {
                            image = mkOption {
                              type = types.enum (builtins.attrNames contractCfg.images);
                            };
                            internalPort = mkOption {
                              type = types.port;
                              default = 3000;
                            };
                            healthPath = mkOption {
                              type = types.nullOr types.str;
                              default = null;
                            };
                            dependsOn = mkOption {
                              type = types.listOf types.str;
                              default = [ ];
                            };
                            readiness = mkOption {
                              type = types.nullOr (
                                types.submodule {
                                  options = {
                                    command = mkOption { type = types.listOf types.str; };
                                    interval = mkOption { type = types.str; };
                                    retries = mkOption { type = types.ints.positive; };
                                    timeout = mkOption { type = types.str; };
                                  };
                                }
                              );
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
                              type = types.enum [ "manual" ];
                              default = "manual";
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
                            service = mkOption {
                              type = types.enum (builtins.attrNames contractCfg.services);
                            };
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
                    release = mkOption {
                      type = types.submodule {
                        options = {
                          versioning = mkOption {
                            type = types.enum [ "external" ];
                            default = "external";
                          };
                          manifestUrl = mkOption {
                            type = types.nullOr types.str;
                            default = null;
                          };
                          channels = mkOption {
                            type = types.attrsOf (
                              types.submodule {
                                options = {
                                  tag = mkOption { type = types.str; };
                                  mode = mkOption {
                                    type = types.enum [
                                      "manual"
                                      "auto"
                                      "approved"
                                    ];
                                    default = "manual";
                                  };
                                  targetPattern = mkOption {
                                    type = types.str;
                                    description = "Anchored regular expression for release targets admitted to this channel.";
                                  };
                                  strategy = mkOption {
                                    type = types.enum [ "coordinated" ];
                                    default = "coordinated";
                                  };
                                  smokePaths = mkOption {
                                    type = types.listOf types.str;
                                    default = [ ];
                                  };
                                  migrate = mkOption {
                                    type = types.enum [
                                      "none"
                                      "manual"
                                    ];
                                    default = "none";
                                  };
                                };
                              }
                            );
                            default = { };
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
                }
              );
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
              postgresPasswordSecret = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "sops secret holding this app's shared-PostgreSQL role password.";
              };
              subnetId = mkOption {
                type = types.nullOr (types.ints.between 1 250);
                default = null;
                description = "Third octet of the app bridge subnet 10.90.<id>.0/24; containers reach host services via the .1 gateway.";
              };
              releaseManifestOrigins = mkOption {
                type = types.listOf types.str;
                default = [ ];
                description = "Host-admitted HTTPS origins allowed to serve release manifests.";
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
                type = types.attrsOf (types.submodule { options = { }; });
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
        assertion = unique unitPrefixes == unitPrefixes;
        message = "homelab.apps entries must render unique <name>-<channel> unit prefixes.";
      }
      {
        assertion = unique subnetIds == subnetIds;
        message = "homelab.apps entries must use unique host.subnetId values.";
      }
    ]
    ++ flatten (mapAttrsToList assertionsForApp enabledApps);

    sops.secrets = sopsSecrets;
    sops.templates = sopsTemplates;

    homelab.publicRoutes = appPublicRoutes;
    homelab.reservedLoopbackPorts = serviceLoopbackPorts;

    networking.firewall.interfaces = appDnsFirewallInterfaces;

    virtualisation.quadlet = {
      networks = quadletNetworks;
      volumes = quadletVolumes;
      containers = quadletContainers;
    };

    homelab.podmanDnsLifecycle.members =
      map (name: "${name}-network.service") (builtins.attrNames quadletNetworks)
      ++ map (name: "${name}.service") (builtins.attrNames quadletContainers);

    environment.etc = metadataEtcEntries;
    environment.systemPackages = [ homelabAppctl ];

    security.sudo.extraRules = [
      {
        users = [ "github-runner-homelab" ];
        runAs = "root";
        commands =
          let
            allowedCommand = command: {
              inherit command;
              options = [ "NOPASSWD" ];
            };
          in
          [
            (allowedCommand "${homelabAppctl}/bin/homelab-appctl deploy *")
            (allowedCommand "/run/current-system/sw/bin/homelab-appctl deploy *")
          ];
      }
    ];

    systemd.services = migrationServices;

    systemd.tmpfiles.rules = [
      "d /var/lib/homelab-appctl 0750 root root - -"
      "d /run/homelab-appctl 0750 root root - -"
    ];
  };
}
