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
      runtimeContractSourceSha256 = app.runtimeContractSourceSha256;
      homelabAdmissionSourceSha256 = app.homelabAdmissionSourceSha256;
      manifestSchemaSourceSha256 = app.manifestSchemaSourceSha256;
      manifestGeneratorSourceSha256 = app.manifestGeneratorSourceSha256;
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
    };

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
  homelabAppctl = pkgs.writeShellApplication {
    name = "homelab-appctl";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.diffutils
      pkgs.findutils
      pkgs.gnugrep
      pkgs.gnused
      pkgs.jq
      pkgs.podman
      pkgs.systemd
      pkgs.util-linux
    ];
    text = ''
      set -euo pipefail

      metadata_root="''${HOMELAB_APPCTL_METADATA_ROOT:-/etc/homelab-apps}"
      state_root="''${HOMELAB_APPCTL_STATE_ROOT:-/var/lib/homelab-appctl}"

      usage() {
        cat <<'EOF'
      Usage:
        homelab-appctl list
        homelab-appctl status <app> <channel>
        homelab-appctl smoke <app> <channel>
        homelab-appctl deploy <app> <channel> --target <release-id> [--dry-run]
        homelab-appctl logs <app> <channel>
      EOF
      }

      die() {
        echo "homelab-appctl: $*" >&2
        exit 1
      }

      require_id() {
        local label=$1
        local value=$2
        [[ "$value" =~ ^[a-z0-9][a-z0-9-]*$ ]] ||
          die "$label must match ^[a-z0-9][a-z0-9-]*$: $value"
      }

      require_target() {
        local value=$1
        [[ "$value" =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] ||
          die "target must match ^[A-Za-z0-9][A-Za-z0-9._-]*$: $value"
      }

      require_app_channel() {
        require_id app "$1"
        require_id channel "$2"
      }

      require_root() {
        local action=$1
        shift
        if [ "$(id -u)" -ne 0 ]; then
          die "$action requires root because it writes $state_root and controls system services; run: sudo -n homelab-appctl $action $*"
        fi
      }

      metadata_path() {
        local app=$1
        local channel=$2
        printf '%s/%s/%s.json\n' "$metadata_root" "$app" "$channel"
      }

      require_metadata() {
        local app=$1
        local channel=$2
        local path
        require_app_channel "$app" "$channel"
        path=$(metadata_path "$app" "$channel")
        [ -f "$path" ] || die "missing metadata: $path"
        printf '%s\n' "$path"
      }

      service_units() {
        jq -r '.services[].serviceUnit' "$1"
      }

      release_units() {
        jq -r '.services[] | select(.releaseManaged) | .serviceUnit' "$1"
      }

      release_images() {
        jq -r '.services[] | select(.releaseManaged) | [.name, .imageKey, .imageName, .imageRef] | @tsv' "$1"
      }

      smoke_paths() {
        jq -r '.smokePaths[]?' "$1"
      }

      snapshot_images() {
        local meta=$1
        jq -r '.services[] | [.name, .imageRef] | @tsv' "$meta" |
          while IFS=$'\t' read -r name image_ref; do
            image_id=$(podman image inspect "$image_ref" --format '{{.Id}}' 2>/dev/null || true)
            printf '%s\t%s\t%s\n' "$name" "$image_ref" "$image_id"
          done
      }

      images_json() {
        local path=$1
        if [ ! -s "$path" ]; then
          printf '[]\n'
          return 0
        fi

        jq -R -s '
          split("\n")
          | map(select(length > 0))
          | map(split("\t") | {
              name: .[0],
              imageRef: .[1],
              imageId: (.[2] // "")
            })
        ' "$path"
      }

      write_record_summary() {
        local record_path=$1
        local app=$2
        local channel=$3
        local target=$4
        local result=$5
        local migration_result=$6
        local smoke_result=$7
        local deployed_at

        deployed_at=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        jq -n \
          --arg app "$app" \
          --arg channel "$channel" \
          --arg target "$target" \
          --arg deployedAt "$deployed_at" \
          --arg result "$result" \
          --arg migrationResult "$migration_result" \
          --arg smokeResult "$smoke_result" \
          --argjson beforeImages "$(images_json "$record_path/before-images.tsv")" \
          --argjson afterImages "$(images_json "$record_path/after-images.tsv")" \
          '{
            app: $app,
            channel: $channel,
            target: (if $target == "" then null else $target end),
            deployedAt: $deployedAt,
            result: $result,
            images: {
              before: $beforeImages,
              after: $afterImages
            },
            migration: {
              result: $migrationResult
            },
            smoke: {
              result: $smokeResult
            }
          }' > "$record_path/summary.json"
      }

      finish_record() {
        local record_dir=$1
        local record_path=$2
        local app=$3
        local channel=$4
        local target=$5
        local result=$6
        local migration_result=$7
        local smoke_result=$8

        printf '%s\n' "$result" > "$record_path/result"
        write_record_summary "$record_path" "$app" "$channel" "$target" "$result" "$migration_result" "$smoke_result"
        ln -sfnT "$record_path" "$record_dir/latest"
      }

      begin_record() {
        local record_dir=$1
        local record_path=$2
        local app=$3
        local channel=$4
        local target=$5
        local migration_result=$6
        local smoke_result=$7

        printf '%s\n' in-progress > "$record_path/result"
        write_record_summary "$record_path" "$app" "$channel" "$target" in-progress "$migration_result" "$smoke_result"
        ln -sfnT "$record_path" "$record_dir/latest"
      }

      current_target() {
        local app=$1
        local channel=$2
        local meta=$3
        local latest="$state_root/$app/$channel/latest"
        if [ -e "$latest/target" ] \
          && [ -e "$latest/result" ] \
          && [ "$(cat "$latest/result")" = ok ] \
          && cmp -s "$meta" "$latest/metadata.json"; then
          cat "$latest/target"
        fi
      }

      manifest_url() {
        local meta=$1
        local target=$2
        local template
        template=$(jq -er '.release.manifestUrl | strings' "$meta")
        [[ "$template" == *'{target}'* ]] || die "release manifest URL is missing {target}: $template"
        printf '%s\n' "''${template//\{target\}/$target}"
      }

      download_manifest() {
        local url=$1
        local output=$2

        case "$url" in
          https://*)
            curl -fsSL --proto '=https' --proto-redir '=https' \
              --retry 3 --connect-timeout 5 --max-time 30 "$url" -o "$output"
            ;;
          file://*)
            if [ "''${HOMELAB_APPCTL_TEST_ALLOW_FILE_URL:-0}" = 1 ] \
              && [ "$(id -u)" -ne 0 ] \
              && [ "$metadata_root" != /etc/homelab-apps ] \
              && [ "$state_root" != /var/lib/homelab-appctl ]; then
              curl -fsSL --proto '=file' --proto-redir '=file' "$url" -o "$output"
            else
              echo "release manifest URL must use HTTPS: $url" >&2
              return 1
            fi
            ;;
          *)
            echo "release manifest URL must use HTTPS: $url" >&2
            return 1
            ;;
        esac
      }

      validate_manifest() {
        local meta=$1
        local manifest=$2
        local target=$3
        local app target_pattern runtime_contract_hash homelab_admission_hash manifest_schema_hash manifest_generator_hash
        app=$(jq -r '.name' "$meta")
        target_pattern=$(jq -er '.release.targetPattern | strings' "$meta")
        runtime_contract_hash=$(jq -r '.runtimeContractSourceSha256' "$meta")
        homelab_admission_hash=$(jq -r '.homelabAdmissionSourceSha256' "$meta")
        manifest_schema_hash=$(jq -r '.manifestSchemaSourceSha256' "$meta")
        manifest_generator_hash=$(jq -r '.manifestGeneratorSourceSha256' "$meta")

        jq -e \
          --arg app "$app" \
          --arg target "$target" \
          --arg targetPattern "$target_pattern" \
          --arg runtimeContractHash "$runtime_contract_hash" \
          --arg homelabAdmissionHash "$homelab_admission_hash" \
          --arg manifestSchemaHash "$manifest_schema_hash" \
          --arg manifestGeneratorHash "$manifest_generator_hash" \
          '.schemaVersion == 1
            and .app == $app
            and .target == $target
            and (.target | test($targetPattern))
            and (.sourceRev | test("^[0-9a-f]{40}$"))
            and .deploymentContract.runtimeSourceSha256 == $runtimeContractHash
            and .deploymentContract.admissionSourceSha256 == $homelabAdmissionHash
            and .deploymentContract.schemaSourceSha256 == $manifestSchemaHash
            and .deploymentContract.generatorSourceSha256 == $manifestGeneratorHash' \
          "$manifest" >/dev/null
      }

      desired_images() {
        local meta=$1
        local manifest=$2
        local service image_key image_name image_ref manifest_name digest

        while IFS=$'\t' read -r service image_key image_name image_ref; do
          manifest_name=$(jq -er --arg key "$image_key" '.images[$key].name | strings' "$manifest") || return 1
          digest=$(jq -er --arg key "$image_key" '.images[$key].digest | strings' "$manifest") || return 1
          if [ "$manifest_name" != "$image_name" ]; then
            echo "manifest image name mismatch for $service: $manifest_name" >&2
            return 1
          fi
          if [[ ! "$digest" =~ ^sha256:[0-9a-f]{64}$ ]]; then
            echo "invalid manifest digest for $service: $digest" >&2
            return 1
          fi
          printf '%s\t%s\t%s\t%s\n' "$service" "$image_ref" "$manifest_name" "$digest"
        done < <(release_images "$meta")
      }

      pull_release_images() {
        local meta=$1
        local desired=$2
        local auth_file service image_ref image_name digest
        local auth_args=()
        auth_file=$(jq -r '.registryAuthFile // empty' "$meta")
        if [ -n "$auth_file" ]; then
          auth_args=(--authfile "$auth_file")
        fi

        while IFS=$'\t' read -r service image_ref image_name digest; do
          echo "pull: $image_name@$digest"
          podman pull "''${auth_args[@]}" "$image_name@$digest" >/dev/null || return 1
        done < "$desired"
      }

      activate_release_images() {
        local desired=$1
        local service image_ref image_name digest
        while IFS=$'\t' read -r service image_ref image_name digest; do
          echo "activate: $image_ref -> $digest"
          podman tag "$image_name@$digest" "$image_ref" || return 1
        done < "$desired"
      }

      restore_release_images() {
        local desired=$1
        local before=$2
        local service image_ref image_name digest before_ref before_id previous_id
        local failed=0

        while IFS=$'\t' read -r service image_ref image_name digest; do
          previous_id=""
          while IFS=$'\t' read -r _ before_ref before_id; do
            if [ "$before_ref" = "$image_ref" ]; then
              previous_id=$before_id
              break
            fi
          done < "$before"

          if [ -n "$previous_id" ]; then
            if ! podman tag "$previous_id" "$image_ref"; then
              echo "failed to restore $image_ref to $previous_id" >&2
              failed=1
            fi
          else
            if ! podman untag "$image_ref" >/dev/null 2>&1; then
              if podman image inspect "$image_ref" >/dev/null 2>&1; then
                echo "failed to remove newly activated tag $image_ref" >&2
                failed=1
              fi
            fi
          fi
        done < "$desired"

        return "$failed"
      }

      cmd_list() {
        if [ ! -d "$metadata_root" ]; then
          return 0
        fi

        find "$metadata_root" -mindepth 2 -maxdepth 2 -name '*.json' -print |
          sort |
          while IFS= read -r meta; do
            jq -r '[.name, .channel, .domain, .unitPrefix] | @tsv' "$meta"
          done
      }

      cmd_status() {
        local meta=$1
        mapfile -t units < <(service_units "$meta")
        [ "''${#units[@]}" -gt 0 ] || die "metadata has no service units"
        systemctl --no-pager status "''${units[@]}"
      }

      cmd_logs() {
        local meta=$1
        local unit
        local args=()
        mapfile -t units < <(service_units "$meta")
        [ "''${#units[@]}" -gt 0 ] || die "metadata has no service units"
        for unit in "''${units[@]}"; do
          args+=(-u "$unit")
        done
        journalctl --no-pager -n 200 "''${args[@]}"
      }

      cmd_smoke() {
        local meta=$1
        local domain caddy_url path attempt max_attempts
        domain=$(jq -r '.domain' "$meta")
        caddy_url=$(jq -r '.caddyUrl' "$meta")
        max_attempts=12
        mapfile -t paths < <(smoke_paths "$meta")
        [ "''${#paths[@]}" -gt 0 ] || die "metadata has no smoke paths"

        for path in "''${paths[@]}"; do
          echo "smoke: $domain $path"
          attempt=1
          until curl -fsS --connect-timeout 2 --max-time 5 -H "Host: $domain" "$caddy_url$path" >/dev/null; do
            if [ "$attempt" -ge "$max_attempts" ]; then
              return 1
            fi
            attempt=$((attempt + 1))
            echo "smoke retry: $domain $path attempt $attempt/$max_attempts" >&2
            sleep 2
          done
        done
      }

      cmd_deploy() {
        local app=$1
        local channel=$2
        local meta=$3
        local dry_run=$4
        local target=$5
        local current release_manifest_url
        local migration_unit record_dir record_path deploy_lock_fd metadata_snapshot
        local migration_result smoke_result result
        local release_service_units=()

        if [ "$dry_run" = 1 ]; then
          local dry_run_dir
          migration_unit=$(jq -r '.migration.unit // empty' "$meta")
          current=$(current_target "$app" "$channel" "$meta" 2>/dev/null || true)
          release_manifest_url=$(manifest_url "$meta" "$target")
          dry_run_dir=$(mktemp -d)
          echo "metadata: $meta"
          if [ -n "$target" ]; then
            echo "target: $target"
            if [ "$current" = "$target" ]; then
              echo "action: no-op; target already deployed"
            else
              echo "action: deploy; current target: ''${current:-none}"
            fi
          fi
          echo "release manifest: $release_manifest_url"
          if ! download_manifest "$release_manifest_url" "$dry_run_dir/release-manifest.json"; then
            rm -rf "$dry_run_dir"
            die "release manifest download failed: $release_manifest_url"
          fi
          if ! validate_manifest "$meta" "$dry_run_dir/release-manifest.json" "$target"; then
            rm -rf "$dry_run_dir"
            die "release manifest does not match admitted metadata: $target"
          fi
          if ! desired_images "$meta" "$dry_run_dir/release-manifest.json" > "$dry_run_dir/desired-images.tsv" \
            || [ ! -s "$dry_run_dir/desired-images.tsv" ]; then
            rm -rf "$dry_run_dir"
            die "release manifest has no valid admitted images"
          fi
          echo "release images:"
          while IFS=$'\t' read -r _ image_ref image_name digest; do
            echo "  $image_name@$digest -> $image_ref"
          done < "$dry_run_dir/desired-images.tsv"
          if [ -n "$migration_unit" ]; then
            echo "migration unit:"
            echo "  $migration_unit"
          else
            echo "migration unit: none"
          fi
          echo "release service units:"
          release_units "$meta" | sed 's/^/  /'
          echo "smoke paths:"
          smoke_paths "$meta" | sed 's/^/  /'
          rm -rf "$dry_run_dir"
          return 0
        fi

        require_root deploy "$app" "$channel"

        record_dir="$state_root/$app/$channel"
        mkdir -p "$record_dir"
        exec {deploy_lock_fd}> "$record_dir/deploy.lock"
        flock -w 900 "$deploy_lock_fd" || die "timed out waiting for deploy lock: $app/$channel"

        metadata_snapshot=$(mktemp)
        cp "$meta" "$metadata_snapshot"
        meta="$metadata_snapshot"
        current=$(current_target "$app" "$channel" "$meta" 2>/dev/null || true)

        if [ -n "$target" ] && [ "$current" = "$target" ]; then
          echo "target already deployed: $target"
          rm -f "$metadata_snapshot"
          return 0
        fi

        record_path=$(mktemp -d "$record_dir/$(date -u +%Y%m%dT%H%M%SZ).XXXXXX")
        cp "$meta" "$record_path/metadata.json"
        rm -f "$metadata_snapshot"
        meta="$record_path/metadata.json"
        sha256sum "$meta" > "$record_path/metadata.sha256"
        if [ -n "$target" ]; then
          printf '%s\n' "$target" > "$record_path/target"
        fi
        migration_unit=$(jq -r '.migration.unit // empty' "$meta")
        release_manifest_url=$(manifest_url "$meta" "$target")
        migration_result=skipped
        if [ -n "$migration_unit" ]; then
          migration_result=not-run
        fi
        smoke_result=not-run
        snapshot_images "$meta" > "$record_path/before-images.tsv"
        begin_record "$record_dir" "$record_path" "$app" "$channel" "$target" "$migration_result" "$smoke_result"

        echo "manifest: $release_manifest_url"
        if ! download_manifest "$release_manifest_url" "$record_path/release-manifest.json"; then
          finish_record "$record_dir" "$record_path" "$app" "$channel" "$target" manifest-download-failed "$migration_result" "$smoke_result"
          return 1
        fi

        if ! validate_manifest "$meta" "$record_path/release-manifest.json" "$target"; then
          finish_record "$record_dir" "$record_path" "$app" "$channel" "$target" manifest-invalid "$migration_result" "$smoke_result"
          return 1
        fi

        if ! desired_images "$meta" "$record_path/release-manifest.json" > "$record_path/desired-images.tsv"; then
          finish_record "$record_dir" "$record_path" "$app" "$channel" "$target" manifest-invalid "$migration_result" "$smoke_result"
          return 1
        fi
        if [ ! -s "$record_path/desired-images.tsv" ]; then
          finish_record "$record_dir" "$record_path" "$app" "$channel" "$target" manifest-invalid "$migration_result" "$smoke_result"
          return 1
        fi

        if ! pull_release_images "$meta" "$record_path/desired-images.tsv"; then
          finish_record "$record_dir" "$record_path" "$app" "$channel" "$target" pull-failed "$migration_result" "$smoke_result"
          return 1
        fi

        if ! activate_release_images "$record_path/desired-images.tsv"; then
          if restore_release_images "$record_path/desired-images.tsv" "$record_path/before-images.tsv"; then
            result=activation-failed
          else
            result=activation-recovery-failed
          fi
          finish_record "$record_dir" "$record_path" "$app" "$channel" "$target" "$result" "$migration_result" "$smoke_result"
          return 1
        fi

        if [ -n "$migration_unit" ]; then
          echo "migrate: $migration_unit"
          if systemctl start "$migration_unit"; then
            migration_result=ok
          else
            migration_result=failed
            if restore_release_images "$record_path/desired-images.tsv" "$record_path/before-images.tsv"; then
              result=migration-failed
            else
              result=migration-recovery-failed
            fi
            finish_record "$record_dir" "$record_path" "$app" "$channel" "$target" "$result" "$migration_result" "$smoke_result"
            return 1
          fi
        fi

        mapfile -t release_service_units < <(release_units "$meta")
        [ "''${#release_service_units[@]}" -gt 0 ] || die "metadata has no release service units"
        echo "restart: ''${release_service_units[*]}"
        if ! systemctl restart "''${release_service_units[@]}"; then
          finish_record "$record_dir" "$record_path" "$app" "$channel" "$target" restart-failed "$migration_result" "$smoke_result"
          return 1
        fi

        snapshot_images "$meta" > "$record_path/after-images.tsv"

        if cmd_smoke "$meta"; then
          smoke_result=ok
          finish_record "$record_dir" "$record_path" "$app" "$channel" "$target" ok "$migration_result" "$smoke_result"
          echo "deploy record: $record_path"
        else
          smoke_result=failed
          finish_record "$record_dir" "$record_path" "$app" "$channel" "$target" smoke-failed "$migration_result" "$smoke_result"
          echo "smoke failed; deploy a known-good release target to roll back: $record_path" >&2
          return 1
        fi
      }

      command=''${1:-}
      case "$command" in
        list)
          [ "$#" -eq 1 ] || die "list takes no arguments"
          cmd_list
          ;;
        status|smoke|logs)
          [ "$#" -eq 3 ] || {
            usage >&2
            exit 1
          }
          app=$2
          channel=$3
          meta=$(require_metadata "$app" "$channel")
          case "$command" in
            status) cmd_status "$meta" ;;
            smoke) cmd_smoke "$meta" ;;
            logs) cmd_logs "$meta" ;;
          esac
          ;;
        deploy)
          [ "$#" -ge 3 ] || {
            usage >&2
            exit 1
          }
          app=$2
          channel=$3
          dry_run=0
          target=""
          shift 3
          while [ "$#" -gt 0 ]; do
            case "$1" in
              --dry-run)
                dry_run=1
                shift
                ;;
              --target)
                [ "$#" -ge 2 ] || die "--target requires a value"
                require_target "$2"
                target=$2
                shift 2
                ;;
              *)
                die "unknown deploy option: $1"
                ;;
            esac
          done
          [ -n "$target" ] || die "deploy requires --target <release-id>"
          meta=$(require_metadata "$app" "$channel")
          cmd_deploy "$app" "$channel" "$meta" "$dry_run" "$target"
          ;;
        -h|--help|help|"")
          usage
          ;;
        *)
          usage >&2
          exit 1
          ;;
      esac
    '';
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
        assertion = builtins.match "^[0-9a-f]{64}$" app.runtimeContractSourceSha256 != null;
        message = "homelab.apps.${appName}: runtimeContractSourceSha256 must be a lowercase SHA-256 hex digest.";
      }
      {
        assertion = builtins.match "^[0-9a-f]{64}$" app.homelabAdmissionSourceSha256 != null;
        message = "homelab.apps.${appName}: homelabAdmissionSourceSha256 must be a lowercase SHA-256 hex digest.";
      }
      {
        assertion = builtins.match "^[0-9a-f]{64}$" app.manifestSchemaSourceSha256 != null;
        message = "homelab.apps.${appName}: manifestSchemaSourceSha256 must be a lowercase SHA-256 hex digest.";
      }
      {
        assertion = builtins.match "^[0-9a-f]{64}$" app.manifestGeneratorSourceSha256 != null;
        message = "homelab.apps.${appName}: manifestGeneratorSourceSha256 must be a lowercase SHA-256 hex digest.";
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
              type = types.str;
              description = "SHA-256 of the app-owned runtime contract source.";
            };

            homelabAdmissionSourceSha256 = mkOption {
              type = types.str;
              description = "SHA-256 of the pinned app-owned homelab admission source.";
            };

            manifestSchemaSourceSha256 = mkOption {
              type = types.str;
              description = "SHA-256 of the pinned app-owned release manifest schema.";
            };

            manifestGeneratorSourceSha256 = mkOption {
              type = types.str;
              description = "SHA-256 of the pinned app-owned release manifest generator.";
            };

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
