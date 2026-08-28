{
  config,
  lib,
  myOptions,
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

  unitPrefixFor = app: "${app.contract.name}-${app.contract.channel}";
  bridgeInterfaceFor = app: "br-${unitPrefixFor app}";

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

  releaseManaged = service: service.updatePolicy == "manual";

  # Contract v2: digest-only admission + platform conventions (PORT, needs.postgres).
  isV2 = app: app.contract.schemaVersion == 2;
  usesSharedPostgres = app: isV2 app && app.contract.needs.postgres;

  # Shared-PostgreSQL role/db name; PostgreSQL identifiers use underscores.
  sharedPostgresNameFor =
    app: lib.replaceStrings [ "-" ] [ "_" ] "${app.contract.name}_${app.contract.channel}";
  appSubnetFor = app: "10.90.${toString app.host.subnetId}.0/24";
  appGatewayFor = app: "10.90.${toString app.host.subnetId}.1";

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

      # v2 convention: containers listen on PORT (= internalPort); contract env wins.
      effectiveEnv =
        lib.optionalAttrs (isV2 app) { PORT = toString service.internalPort; } // service.env;
      envLines = mapAttrsToList (key: value: "${key}=${value}") effectiveEnv;
      secretLines = map secretLine service.requiredSecretEnv;
      platformLines = lib.optional (usesSharedPostgres app) (
        "DATABASE_URL=postgresql://${sharedPostgresNameFor app}:"
        + builtins.getAttr app.host.postgresPasswordSecret config.sops.placeholder
        + "@${appGatewayFor app}:5432/${sharedPostgresNameFor app}"
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

  quadletImageFor =
    app: serviceName: service:
    let
      authFile = registryAuthFileFor app;
      unitPrefix = unitPrefixFor app;
    in
    nameValuePair "${unitPrefix}-${serviceName}" {
      autoStart = false;
      unitConfig = {
        Description = "Pull ${unitPrefix}-${serviceName} image";
        After = lib.optional (authFile != null) "sops-install-secrets.service";
      }
      // lib.optionalAttrs (authFile != null) {
        Requires = [ "sops-install-secrets.service" ];
      };
      imageConfig = {
        image = imageRefFor app service;
        authFile = authFile;
      };
    };

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
      authFile = registryAuthFileFor app;
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
        ++ dependencyServices;
        After = [
          "sops-install-secrets.service"
          podmanDnsLifecycleService
        ]
        ++ dependencyServices;
        PartOf = [
          networkService
          podmanDnsLifecycleService
        ];
      };
      containerConfig = {
        name = "${unitPrefix}-${serviceName}";
        image =
          if releaseManaged service then imageRefFor app service else "${unitPrefix}-${serviceName}.image";
        pull = "never";
        autoUpdate = if service.updatePolicy == "registry-auto" then "registry" else null;
        labels = lib.optionalAttrs (service.updatePolicy == "registry-auto" && authFile != null) {
          "io.containers.autoupdate.authfile" = authFile;
        };
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
      }
      // lib.optionalAttrs (isV2 app) {
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
      networkService = "${unitPrefix}-network.service";
      imageService = "${unitPrefix}-${migrationServiceName}-image.service";
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
      ++ lib.optional (!releaseManaged service) imageService
      ++ dependencyServices
      ++ volumeServices;
      after = [
        "sops-install-secrets.service"
        "network-online.target"
        networkService
      ]
      ++ lib.optional (!releaseManaged service) imageService
      ++ dependencyServices
      ++ volumeServices;
      serviceConfig.Type = "oneshot";
      script = ''
        ${pkgs.podman}/bin/podman rm -f ${lib.escapeShellArg "${unitPrefix}-migrate"} >/dev/null 2>&1 || true
        exec ${pkgs.podman}/bin/podman run --rm --pull=never --name ${lib.escapeShellArg "${unitPrefix}-migrate"} --env-file ${lib.escapeShellArg envTemplate} --network ${lib.escapeShellArg unitPrefix} ${volumeArgs} ${lib.escapeShellArg imageRef} ${lib.escapeShellArgs contract.migrations.command}
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
      servicePorts = portMapFor app.contract.services app.host.loopbackPortBase;
    in
    {
      name = serviceName;
      imageKey = service.image;
      imageRef = imageRefFor app service;
      imageName = if releaseManaged service then releaseImageNameFor app service else null;
      imageUnit = if releaseManaged service then null else "${unitPrefix}-${serviceName}-image.service";
      releaseManaged = releaseManaged service;
      serviceUnit = "${unitPrefix}-${serviceName}.service";
      containerName = "${unitPrefix}-${serviceName}";
      internalPort = service.internalPort;
      loopbackPort = servicePorts.${serviceName};
      healthPath = service.healthPath;
      dependsOn = service.dependsOn;
      updatePolicy = service.updatePolicy;
    };

  appMetadataFor =
    appName: app:
    let
      releaseChannel = releaseChannelFor app;
      unitPrefix = unitPrefixFor app;
      caddyPort = caddyPortFor app;
    in
    {
      appKey = appName;
      name = app.contract.name;
      channel = app.contract.channel;
      unitPrefix = unitPrefix;
      domain = app.host.domain;
      caddyUrl = "http://127.0.0.1:${toString caddyPort}";
      registryAuthFile = registryAuthFileFor app;
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
            mode = releaseChannel.mode;
            targetPattern = releaseChannel.targetPattern;
            strategy = releaseChannel.strategy;
            migrate = releaseChannel.migrate;
            smokePaths = releaseChannel.smokePaths;
          };
    }
    // lib.optionalAttrs (!isV2 app) {
      runtimeContractSourceSha256 = app.runtimeContractSourceSha256;
      homelabAdmissionSourceSha256 = app.homelabAdmissionSourceSha256;
      manifestSchemaSourceSha256 = app.manifestSchemaSourceSha256;
      manifestGeneratorSourceSha256 = app.manifestGeneratorSourceSha256;
    }
    // lib.optionalAttrs (isV2 app) { contractVersion = 2; };

  metadataEtcFor =
    appName: app:
    nameValuePair "homelab-apps/${app.contract.name}/${app.contract.channel}.json" {
      text = builtins.toJSON (appMetadataFor appName app) + "\n";
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
  quadletImages = listToAttrs (
    flatten (
      mapAttrsToList (
        _appName: app:
        mapAttrsToList (quadletImageFor app) (
          filterAttrs (_serviceName: service: !releaseManaged service) app.contract.services
        )
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
      imageNames = builtins.attrNames contract.images;
      volumeNames = builtins.attrNames contract.volumes;
      hostVolumeNames = builtins.attrNames app.host.volumes;
      releaseChannels = contract.release.channels;
      migrationMode = contract.migrations.mode;
      migrationService = contract.migrations.service;
      registryAutoServices = filterAttrs (
        _: service: service.updatePolicy == "registry-auto"
      ) contract.services;
      migrationServiceIsRegistryAuto =
        migrationService != null && builtins.hasAttr migrationService registryAutoServices;
      manualServices = filterAttrs (_: service: releaseManaged service) contract.services;
      sourceHashes = [
        app.runtimeContractSourceSha256
        app.homelabAdmissionSourceSha256
        app.manifestSchemaSourceSha256
        app.manifestGeneratorSourceSha256
      ];
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
      {
        assertion =
          isV2 app
          || builtins.all (hash: hash != null && builtins.match "^[0-9a-f]{64}$" hash != null) sourceHashes;
        message = "homelab.apps.${appName}: schemaVersion 1 requires all four deployment source hashes as lowercase SHA-256 hex digests.";
      }
      {
        assertion = !isV2 app || builtins.all (hash: hash == null) sourceHashes;
        message = "homelab.apps.${appName}: schemaVersion 2 admits releases by digest only; source hashes must not be set.";
      }
      {
        assertion = !isV2 app || app.host.subnetId != null;
        message = "homelab.apps.${appName}: schemaVersion 2 requires host.subnetId (bridge subnet 10.90.<id>.0/24).";
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
          manualServices == { } || (releaseChannelFor app != null && contract.release.manifestUrl != null);
        message = "homelab.apps.${appName}: manual services require release channel metadata and a manifestUrl.";
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
        assertion =
          manualServices == { }
          || builtins.any (
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
            assertion = channel.migrate != "manual" || migrationMode == "manual";
            message = "homelab.apps.${appName}: release channel ${channelName} cannot request manual migration when contract.migrations.mode is not manual.";
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
              !releaseManaged service
              || (
                releaseChannelFor app != null
                && lib.hasSuffix ":${(releaseChannelFor app).tag}" (imageRefFor app service)
              );
            message = "homelab.apps.${appName}.${serviceName}: manual image refs must end with the admitted release channel tag.";
          }
          {
            assertion =
              service.updatePolicy != "pinned-digest"
              || builtins.match ".*@sha256:[0-9a-f]{64}$" (imageRefFor app service) != null;
            message = "homelab.apps.${appName}.${serviceName}: pinned-digest image refs must end with @sha256:<64 lowercase hex>.";
          }
          {
            assertion = builtins.elem "${unitPrefixFor app}-${serviceName}" (
              (quadletContainerFor app serviceName service).value.containerConfig.networkAliases
            );
            message = "homelab.apps.${appName}.${serviceName}: generated container must declare its network DNS alias.";
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
  unitPrefixes = mapAttrsToList (_appName: app: unitPrefixFor app) enabledApps;
  v2SubnetIds = builtins.filter (id: id != null) (
    mapAttrsToList (_appName: app: if isV2 app then app.host.subnetId else null) enabledApps
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

            runtimeContractSourceSha256 = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "SHA-256 of the app-owned runtime contract source (schemaVersion 1 only).";
            };

            homelabAdmissionSourceSha256 = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "SHA-256 of the pinned app-owned homelab admission source (schemaVersion 1 only).";
            };

            manifestSchemaSourceSha256 = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "SHA-256 of the pinned app-owned release manifest schema (schemaVersion 1 only).";
            };

            manifestGeneratorSourceSha256 = mkOption {
              type = types.nullOr types.str;
              default = null;
              description = "SHA-256 of the pinned app-owned release manifest generator (schemaVersion 1 only).";
            };

            contract = mkOption {
              type = types.submodule {
                options = {
                  name = mkOption { type = types.str; };
                  channel = mkOption { type = types.str; };
                  schemaVersion = mkOption {
                    type = types.enum [
                      1
                      2
                    ];
                    default = 1;
                    description = "Contract schema version. v2 admits releases by digest only and enables the PORT and needs.postgres platform conventions.";
                  };
                  needs = mkOption {
                    type = types.submodule {
                      options.postgres = mkOption {
                        type = types.bool;
                        default = false;
                        description = "Provision a role/database on the shared host PostgreSQL and inject DATABASE_URL (schemaVersion 2 only).";
                      };
                    };
                    default = { };
                  };
                  images = mkOption { type = types.attrsOf types.str; };
                  services = mkOption {
                    type = types.attrsOf (
                      types.submodule {
                        options = {
                          image = mkOption { type = types.str; };
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
              postgresPasswordSecret = mkOption {
                type = types.nullOr types.str;
                default = null;
                description = "sops secret holding this app's shared-PostgreSQL role password (schemaVersion 2 with needs.postgres).";
              };
              subnetId = mkOption {
                type = types.nullOr (types.ints.between 1 250);
                default = null;
                description = "Third octet of the v2 app bridge subnet 10.90.<id>.0/24; containers reach host services via the .1 gateway.";
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
      {
        assertion = unique unitPrefixes == unitPrefixes;
        message = "homelab.apps entries must render unique <name>-<channel> unit prefixes.";
      }
      {
        assertion = unique v2SubnetIds == v2SubnetIds;
        message = "homelab.apps v2 entries must use unique host.subnetId values.";
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

    networking.firewall.interfaces = appDnsFirewallInterfaces;

    virtualisation.quadlet = {
      networks = quadletNetworks;
      volumes = quadletVolumes;
      images = quadletImages;
      containers = quadletContainers;
    };

    homelab.podmanDnsLifecycle.members =
      map (name: "${name}-network.service") (builtins.attrNames quadletNetworks)
      ++ map (name: "${name}.service") (builtins.attrNames quadletContainers);

    environment.etc = metadataEtcEntries;
    environment.systemPackages = [ homelabAppctl ];

    security.sudo.extraRules = [
      {
        users = [
          myOptions.userName
          "github-runner-homelab"
        ];
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
    ];
  };
}
