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

  releaseChannelFor =
    app:
    if builtins.hasAttr app.contract.channel app.contract.release.channels then
      app.contract.release.channels.${app.contract.channel}
    else
      null;

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
      volumes = map (mount: mountLineFor app mount) service.volumeMounts;
    in
    nameValuePair "${unitPrefix}-${serviceName}" {
      unitConfig = {
        Description = "${app.contract.name} ${app.contract.channel} ${serviceName} container";
        Requires = [
          "sops-install-secrets.service"
          podmanDnsLifecycleService
        ];
        After = [
          "sops-install-secrets.service"
          podmanDnsLifecycleService
        ];
        PartOf = [
          networkService
          podmanDnsLifecycleService
        ];
      };
      containerConfig = {
        name = "${unitPrefix}-${serviceName}";
        image = "${unitPrefix}-${serviceName}.image";
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
      networkConfig.name = unitPrefix;
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
        imageService
      ]
      ++ volumeServices;
      after = [
        "sops-install-secrets.service"
        "network-online.target"
        networkService
        imageService
      ]
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
      imageUnit = "${unitPrefix}-${serviceName}-image.service";
      serviceUnit = "${unitPrefix}-${serviceName}.service";
      containerName = "${unitPrefix}-${serviceName}";
      internalPort = service.internalPort;
      loopbackPort = servicePorts.${serviceName};
      healthPath = service.healthPath;
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
            tag = releaseChannel.tag;
            mode = releaseChannel.mode;
            strategy = releaseChannel.strategy;
            migrate = releaseChannel.migrate;
            rollback = releaseChannel.rollback;
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
        _appName: app: mapAttrsToList (quadletImageFor app) app.contract.services
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
      pkgs.findutils
      pkgs.gnugrep
      pkgs.jq
      pkgs.podman
      pkgs.systemd
    ];
    text = ''
      set -euo pipefail

      metadata_root=/etc/homelab-apps
      state_root=/var/lib/homelab-appctl

      usage() {
        cat <<'EOF'
      Usage:
        homelab-appctl list
        homelab-appctl status <app> <channel>
        homelab-appctl smoke <app> <channel>
        homelab-appctl deploy <app> <channel> [--dry-run] [--target <identifier>]
        homelab-appctl rollback <app> <channel>
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
        [[ "$value" =~ ^[A-Za-z0-9._:-]+$ ]] ||
          die "target must match ^[A-Za-z0-9._:-]+$: $value"
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

      image_units() {
        jq -r '.services[].imageUnit' "$1"
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

      current_target() {
        local app=$1
        local channel=$2
        local latest="$state_root/$app/$channel/latest"
        if [ -e "$latest/target" ] && [ -e "$latest/result" ] && [ "$(cat "$latest/result")" = ok ]; then
          cat "$latest/target"
        fi
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
        local current
        local migration_unit record_dir record_path
        local migration_result smoke_result image_unit service_unit

        migration_unit=$(jq -r '.migration.unit // empty' "$meta")
        current=$(current_target "$app" "$channel" 2>/dev/null || true)

        if [ "$dry_run" = 1 ]; then
          echo "metadata: $meta"
          if [ -n "$target" ]; then
            echo "target: $target"
            if [ "$current" = "$target" ]; then
              echo "action: no-op; target already deployed"
            else
              echo "action: deploy; current target: ''${current:-none}"
            fi
          fi
          echo "image units:"
          image_units "$meta" | sed 's/^/  /'
          if [ -n "$migration_unit" ]; then
            echo "migration unit:"
            echo "  $migration_unit"
          else
            echo "migration unit: none"
          fi
          echo "service units:"
          service_units "$meta" | sed 's/^/  /'
          echo "smoke paths:"
          smoke_paths "$meta" | sed 's/^/  /'
          return 0
        fi

        require_root deploy "$app" "$channel"

        if [ -n "$target" ] && [ "$current" = "$target" ]; then
          echo "target already deployed: $target"
          return 0
        fi

        record_dir="$state_root/$app/$channel"
        record_path="$record_dir/$(date -u +%Y%m%dT%H%M%SZ)"
        mkdir -p "$record_path"
        cp "$meta" "$record_path/metadata.json"
        sha256sum "$meta" > "$record_path/metadata.sha256"
        if [ -n "$target" ]; then
          printf '%s\n' "$target" > "$record_path/target"
        fi
        migration_result=skipped
        if [ -n "$migration_unit" ]; then
          migration_result=not-run
        fi
        smoke_result=not-run
        snapshot_images "$meta" > "$record_path/before-images.tsv"

        if ! systemctl daemon-reload; then
          finish_record "$record_dir" "$record_path" "$app" "$channel" "$target" restart-failed "$migration_result" "$smoke_result"
          return 1
        fi

        while IFS= read -r image_unit; do
          echo "pull: $image_unit"
          if ! systemctl restart "$image_unit"; then
            finish_record "$record_dir" "$record_path" "$app" "$channel" "$target" pull-failed "$migration_result" "$smoke_result"
            return 1
          fi
        done < <(image_units "$meta")

        if [ -n "$migration_unit" ]; then
          echo "migrate: $migration_unit"
          if systemctl start "$migration_unit"; then
            migration_result=ok
          else
            migration_result=failed
            finish_record "$record_dir" "$record_path" "$app" "$channel" "$target" migration-failed "$migration_result" "$smoke_result"
            return 1
          fi
        fi

        while IFS= read -r service_unit; do
          echo "restart: $service_unit"
          if ! systemctl restart "$service_unit"; then
            finish_record "$record_dir" "$record_path" "$app" "$channel" "$target" restart-failed "$migration_result" "$smoke_result"
            return 1
          fi
        done < <(service_units "$meta")

        snapshot_images "$meta" > "$record_path/after-images.tsv"

        if cmd_smoke "$meta"; then
          smoke_result=ok
          finish_record "$record_dir" "$record_path" "$app" "$channel" "$target" ok "$migration_result" "$smoke_result"
          echo "deploy record: $record_path"
        else
          smoke_result=failed
          finish_record "$record_dir" "$record_path" "$app" "$channel" "$target" smoke-failed "$migration_result" "$smoke_result"
          echo "smoke failed; rollback record: $record_path" >&2
          echo "run: sudo -n homelab-appctl rollback $app $channel" >&2
          return 1
        fi
      }

      cmd_rollback() {
        local app=$1
        local channel=$2
        local record_dir latest

        require_root rollback "$app" "$channel"

        record_dir="$state_root/$app/$channel"
        latest="$record_dir/latest"
        [ -e "$latest" ] || die "no deploy record found for $app $channel"

        echo "automatic rollback is not enabled yet for $app $channel"
        echo "latest deploy record: $(readlink "$latest" || printf '%s' "$latest")"
        echo "previous images:"
        cat "$latest/before-images.tsv"
        return 2
      }

      command=''${1:-}
      case "$command" in
        list)
          [ "$#" -eq 1 ] || die "list takes no arguments"
          cmd_list
          ;;
        status|smoke|logs|rollback)
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
            rollback) cmd_rollback "$app" "$channel" ;;
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
                  release = mkOption {
                    type = types.submodule {
                      options = {
                        versioning = mkOption {
                          type = types.enum [ "external" ];
                          default = "external";
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
                                rollback = mkOption {
                                  type = types.enum [ "record-only" ];
                                  default = "record-only";
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
            (allowedCommand "${homelabAppctl}/bin/homelab-appctl rollback *")
            (allowedCommand "/run/current-system/sw/bin/homelab-appctl deploy *")
            (allowedCommand "/run/current-system/sw/bin/homelab-appctl rollback *")
          ];
      }
    ];

    systemd.services = migrationServices;

    systemd.tmpfiles.rules = [
      "d /var/lib/homelab-appctl 0750 root root - -"
    ];
  };
}
