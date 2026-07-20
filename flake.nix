{
  description = "A highly awesome system configuration.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgsPwgen.url = "github:nixos/nixpkgs/4533d9293756b63904b7238acb84ac8fe4c8c2c4";
    treefmt-nix = {
      url = "github:numtide/treefmt-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    darwin = {
      url = "github:lnl7/nix-darwin/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    comin = {
      url = "github:nlewo/comin";
      inputs.nixpkgs.follows = "nixpkgs";
    };

    quadlet-nix.url = "github:SEIAROTg/quadlet-nix";

    deopjibRuntime = {
      url = "github:rjcnd105/my-app";
      flake = false;
    };

  };

  outputs =
    inputs@{
      self,
      nixpkgs,
      nixpkgsPwgen,
      treefmt-nix,
      home-manager,
      darwin,
      sops-nix,
      comin,
      quadlet-nix,
      deopjibRuntime,
    }:
    let
      # 형태는 ${host}_${username}
      hosts = {
        workspace_hj = {
          system = "aarch64-darwin";
          email = "rjcnd123@gmail.com";
          projectPath = "/Users/hj/dot/nix-dots";
        };
        homelab_hj = {
          system = "x86_64-linux";
          email = "rjcnd123@gmail.com";
          filesHost = "workspace";
          projectPath = "/etc/nixos";
        };
      };
      lib = nixpkgs.lib;
      systems = [
        "aarch64-darwin"
        "x86_64-linux"
      ];
      eachSystem = lib.genAttrs systems;
      myLib = import ./config/lib.nix {
        inherit lib;
        pkgs = nixpkgs;
      };

      getModulePaths =
        prefix: system: host: user:
        builtins.filter builtins.pathExists [
          ./${prefix}/default.nix
          ./${prefix}/${system}/default.nix
          ./${prefix}/${system}/${host}/default.nix
          ./${prefix}/${system}/${host}/${user}/default.nix
          ./${prefix}/${host}/default.nix
          ./${prefix}/${host}/${user}/default.nix
        ];

      darwinHosts = lib.filterAttrs (_: v: lib.hasSuffix "darwin" v.system) hosts;
      linuxHosts = lib.filterAttrs (_: v: lib.hasSuffix "linux" v.system) hosts;

      parseHostKey =
        key: config:
        let
          split = builtins.split "_" key;
          hostName = builtins.elemAt split 0;
          userName = builtins.elemAt split 2;
        in
        {
          inherit hostName userName;
          myOptions = {
            inherit key;
            inherit (config) email system;
            inherit hostName userName;
            filesHost = config.filesHost or hostName;
            paths = myLib.config.paths;
            absoluteProjectPath = config.projectPath;
            _debug = { };
          };
        };

      nixpkgsConfig = system: {
        inherit system;
        overlays = [
          (_final: _prev: {
            pwgen = nixpkgsPwgen.legacyPackages.${system}.pwgen;
            direnv = _prev.direnv.overrideAttrs (old: {
              doCheck = false;
            });
          })
        ];
        config = {
          allowUnfreePredicate =
            pkg:
            builtins.elem (lib.getName pkg) [
              "vault"
              "claude-code"
            ];
        };
      };

      pkgsFor = system: import nixpkgs (nixpkgsConfig system);

      treefmtModule =
        { ... }:
        {
          projectRootFile = "flake.nix";

          programs = {
            nixfmt.enable = true;
            taplo.enable = true;
          };

          settings.global.on-unmatched = "info";
        };

      treefmtEval = eachSystem (system: treefmt-nix.lib.evalModule (pkgsFor system) treefmtModule);

      homelabAppctlTestContext =
        let
          pkgs = pkgsFor "x86_64-linux";
          homelab = self.nixosConfigurations.homelab_hj.config;
          appctl =
            lib.findFirst (package: lib.getName package == "homelab-appctl")
              (throw "homelab-appctl is missing from the homelab system packages")
              homelab.environment.systemPackages;
          metadata = pkgs.writeText "deopjib-dev-metadata.json" (
            homelab.environment.etc."homelab-apps/deopjib/dev.json".text
          );
          releaseManifest =
            pkgs.runCommand "deopjib-release-manifest-fixture"
              {
                nativeBuildInputs = [
                  pkgs.check-jsonschema
                  pkgs.coreutils
                  pkgs.jq
                ];
              }
              ''
                ${pkgs.bash}/bin/bash ${deopjibRuntime}/scripts/deopjib-generate-release-manifest \
                  --version 0.0.0-dev.0000000 \
                  --source-rev 0000000000000000000000000000000000000000 \
                  --backend-name ghcr.io/rjcnd105/deopjib-backend \
                  --backend-tag 0000000000000000000000000000000000000000 \
                  --backend-digest sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa \
                  --backend-status changed \
                  --web-name ghcr.io/rjcnd105/deopjib-web \
                  --web-tag 0000000000000000000000000000000000000000 \
                  --web-digest sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb \
                  --web-status changed \
                  --deployment-contract-status changed \
                --runtime-contract-source ${deopjibRuntime}/deopjib/devops/runtime-contract.nix \
                --homelab-admission-source ${deopjibRuntime}/deopjib/devops/homelab-admission.nix \
                --manifest-schema-source ${deopjibRuntime}/deopjib/devops/release-manifest.schema.json \
                --manifest-generator-source ${deopjibRuntime}/scripts/deopjib-generate-release-manifest \
                  --generated-at 2026-07-20T00:00:00Z \
                  --output "$out"
                check-jsonschema \
                  --schemafile ${deopjibRuntime}/deopjib/devops/release-manifest.schema.json \
                  "$out"
              '';
        in
        {
          inherit
            appctl
            metadata
            pkgs
            releaseManifest
            ;
        };

      homelabAppctlDeployInvariants =
        system:
        let
          pkgs = pkgsFor system;
        in
        pkgs.runCommand "homelab-appctl-deploy-invariants" { } ''
          app_containers=${./systems/homelab/app-containers.nix}

          ${pkgs.gnugrep}/bin/grep -F 'podman pull' "$app_containers" >/dev/null
          ${pkgs.gnugrep}/bin/grep -F 'podman tag' "$app_containers" >/dev/null
          ${pkgs.gnugrep}/bin/grep -F 'mapfile -t release_service_units' "$app_containers" >/dev/null
          [ "$(${pkgs.gnugrep}/bin/grep -Fc 'systemctl restart ' "$app_containers")" -eq 1 ]
          if ${pkgs.gnugrep}/bin/grep -F 'systemctl restart "$image_unit"' "$app_containers" >/dev/null; then
            echo 'homelab-appctl must pull exact release digests without restarting Quadlet image units' >&2
            exit 1
          fi

          touch "$out"
        '';

      homelabAppctlReleaseDryRun =
        let
          inherit (homelabAppctlTestContext)
            appctl
            metadata
            pkgs
            releaseManifest
            ;
        in
        pkgs.runCommand "homelab-appctl-release-dry-run"
          {
            nativeBuildInputs = [
              appctl
              pkgs.gnugrep
              pkgs.jq
            ];
          }
          ''
            set -eu

            target=deopjib-v0.0.0-dev.0000000
            metadata_root="$PWD/metadata"
            state_root="$PWD/state"
            manifest="$PWD/release-manifest-$target.json"
            manifest_template="file://$PWD/release-manifest-{target}.json"
            mkdir -p "$metadata_root/deopjib" "$state_root"

            backend_name=$(jq -r '.services[] | select(.imageKey == "backend") | .imageName' ${metadata})
            web_name=$(jq -r '.services[] | select(.imageKey == "web") | .imageName' ${metadata})
            install -m 0644 ${releaseManifest} "$manifest"

            jq --arg manifestUrl "$manifest_template" \
              '.release.manifestUrl = $manifestUrl' \
              ${metadata} > "$metadata_root/deopjib/dev.json"

            HOMELAB_APPCTL_METADATA_ROOT="$metadata_root" \
              HOMELAB_APPCTL_STATE_ROOT="$state_root" \
              HOMELAB_APPCTL_TEST_ALLOW_FILE_URL=1 \
              homelab-appctl deploy deopjib dev --target "$target" --dry-run > dry-run.out

            grep -F "$backend_name@sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa" dry-run.out >/dev/null
            grep -F "$web_name@sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" dry-run.out >/dev/null
            grep -F 'deopjib-dev-backend.service' dry-run.out >/dev/null
            grep -F 'deopjib-dev-web.service' dry-run.out >/dev/null
            grep -F 'deopjib-dev-migrate.service' dry-run.out >/dev/null
            if grep -F 'deopjib-dev-db.service' dry-run.out >/dev/null; then
              echo 'release dry-run must not include the pinned database service' >&2
              exit 1
            fi

            cp "$manifest" valid-manifest.json
            expect_rejected() {
              label=$1
              filter=$2
              jq "$filter" valid-manifest.json > "$manifest"
              if HOMELAB_APPCTL_METADATA_ROOT="$metadata_root" \
                HOMELAB_APPCTL_STATE_ROOT="$state_root" \
                HOMELAB_APPCTL_TEST_ALLOW_FILE_URL=1 \
                homelab-appctl deploy deopjib dev --target "$target" --dry-run >/dev/null 2>&1; then
                echo "release dry-run accepted invalid manifest: $label" >&2
                exit 1
              fi
            }

            expect_rejected schema-version '.schemaVersion = 2'
            expect_rejected target '.target = "deopjib-v0.0.0-dev.1111111"'
            expect_rejected runtime-hash '.deploymentContract.runtimeSourceSha256 = ("0" * 64)'
            expect_rejected admission-hash '.deploymentContract.admissionSourceSha256 = ("0" * 64)'
            expect_rejected schema-hash '.deploymentContract.schemaSourceSha256 = ("0" * 64)'
            expect_rejected generator-hash '.deploymentContract.generatorSourceSha256 = ("0" * 64)'
            expect_rejected backend-name '.images.backend.name = "ghcr.io/rjcnd105/not-admitted"'
            expect_rejected backend-digest '.images.backend.digest = "sha256:not-a-digest"'

            cp dry-run.out "$out"
          '';

      homelabAppctlReleaseTransaction =
        let
          inherit (homelabAppctlTestContext)
            appctl
            metadata
            pkgs
            releaseManifest
            ;
        in
        pkgs.runCommand "homelab-appctl-release-transaction"
          {
            nativeBuildInputs = [
              appctl
              pkgs.coreutils
              pkgs.gawk
              pkgs.gnugrep
              pkgs.jq
              pkgs.util-linux
            ];
          }
          ''
            set -euo pipefail

            target=deopjib-v0.0.0-dev.0000000
            metadata_root="$PWD/metadata"
            state_root="$PWD/state"
            image_state="$PWD/images"
            export HOMELAB_APPCTL_METADATA_ROOT="$metadata_root"
            export HOMELAB_APPCTL_STATE_ROOT="$state_root"
            export HOMELAB_APPCTL_TEST_LOG="$PWD/commands.log"
            export HOMELAB_APPCTL_TEST_MANIFEST=${releaseManifest}
            export HOMELAB_APPCTL_TEST_IMAGE_STATE="$image_state"
            export HOMELAB_APPCTL_TEST_FAIL_MARKER="$PWD/migration-failed"
            export HOMELAB_APPCTL_TEST_FAIL_MIGRATION=0
            export HOMELAB_APPCTL_TEST_FAIL_RESTORE=0
            mkdir -p "$metadata_root/deopjib" "$state_root" "$image_state"
            : > "$HOMELAB_APPCTL_TEST_LOG"
            printf '%s\n' backend-old > "$image_state/backend"
            printf '%s\n' web-old > "$image_state/web"

            jq --arg manifestUrl 'https://fixture.invalid/{target}/release.json' \
              '.release.manifestUrl = $manifestUrl' \
              ${metadata} > "$metadata_root/deopjib/dev.json"

            id() {
              if [ "$1" = -u ]; then
                printf '0\n'
                return 0
              fi
              command id "$@"
            }

            curl() {
              printf 'curl\t%s\n' "$*" >> "$HOMELAB_APPCTL_TEST_LOG"
              local output="" url="" requested_target version
              while [ "$#" -gt 0 ]; do
                case "$1" in
                  -o)
                    output=$2
                    shift 2
                    ;;
                  https://*)
                    url=$1
                    shift
                    ;;
                  *) shift ;;
                esac
              done
              if [ -n "$output" ]; then
                requested_target=$(printf '%s\n' "$url" | cut -d/ -f4)
                version="''${requested_target#deopjib-v}"
                jq --arg target "$requested_target" --arg version "$version" '
                  .target = $target
                  | .version = $version
                  | if $target == "deopjib-v1.0.1" or $target == "deopjib-v1.0.2"
                    then .images.backend.digest = ("c" * 64 | "sha256:" + .)
                      | .images.web.digest = ("d" * 64 | "sha256:" + .)
                    else . end
                ' "$HOMELAB_APPCTL_TEST_MANIFEST" > "$output"
              fi
            }

            podman() {
              printf 'podman\t%s\n' "$*" >> "$HOMELAB_APPCTL_TEST_LOG"
              case "$1" in
                image)
                  case "$3" in
                    *deopjib-backend:dev-current) cat "$HOMELAB_APPCTL_TEST_IMAGE_STATE/backend" ;;
                    *deopjib-web:dev-current) cat "$HOMELAB_APPCTL_TEST_IMAGE_STATE/web" ;;
                    *) printf 'db-pinned\n' ;;
                  esac
                  ;;
                pull) ;;
                tag)
                  if [ "$HOMELAB_APPCTL_TEST_FAIL_RESTORE" = 1 ] \
                    && [ -e "$HOMELAB_APPCTL_TEST_FAIL_MARKER" ]; then
                    return 1
                  fi
                  case "$3" in
                    *deopjib-backend:dev-current) printf '%s\n' "$2" > "$HOMELAB_APPCTL_TEST_IMAGE_STATE/backend" ;;
                    *deopjib-web:dev-current) printf '%s\n' "$2" > "$HOMELAB_APPCTL_TEST_IMAGE_STATE/web" ;;
                    *) return 1 ;;
                  esac
                  ;;
                untag)
                  case "$2" in
                    *deopjib-backend:dev-current) : > "$HOMELAB_APPCTL_TEST_IMAGE_STATE/backend" ;;
                    *deopjib-web:dev-current) : > "$HOMELAB_APPCTL_TEST_IMAGE_STATE/web" ;;
                  esac
                  ;;
                *) return 1 ;;
              esac
            }

            systemctl() {
              printf 'systemctl\t%s\n' "$*" >> "$HOMELAB_APPCTL_TEST_LOG"
              if [ "$1" = start ] && [ "$HOMELAB_APPCTL_TEST_FAIL_MIGRATION" = 1 ]; then
                touch "$HOMELAB_APPCTL_TEST_FAIL_MARKER"
                return 1
              fi
              if [ "$1" = restart ]; then
                printf 'restart-begin\t%s\n' "$BASHPID" >> "$HOMELAB_APPCTL_TEST_LOG"
                sleep 0.2
                printf 'restart-end\t%s\n' "$BASHPID" >> "$HOMELAB_APPCTL_TEST_LOG"
              fi
            }

            export -f id curl podman systemctl

            homelab-appctl deploy deopjib dev --target "$target"
            latest="$state_root/deopjib/dev/latest"
            [ "$(cat "$latest/result")" = ok ]
            [ "$(grep -c '^systemctl[[:space:]]restart' "$HOMELAB_APPCTL_TEST_LOG")" -eq 1 ]
            grep -F $'systemctl\trestart deopjib-dev-backend.service deopjib-dev-web.service' "$HOMELAB_APPCTL_TEST_LOG" >/dev/null
            if grep -E '^systemctl[[:space:]]restart .*deopjib-dev-db.service' "$HOMELAB_APPCTL_TEST_LOG" >/dev/null; then
              echo 'release transaction restarted PostgreSQL' >&2
              exit 1
            fi
            [ "$(grep -c '^systemctl[[:space:]]start deopjib-dev-migrate.service' "$HOMELAB_APPCTL_TEST_LOG")" -eq 1 ]
            [ "$(grep -c '^podman[[:space:]]pull ' "$HOMELAB_APPCTL_TEST_LOG")" -eq 2 ]

            cp "$HOMELAB_APPCTL_TEST_LOG" before-noop.log
            PATH=/does-not-exist ${appctl}/bin/homelab-appctl deploy deopjib dev --target "$target"
            cmp before-noop.log "$HOMELAB_APPCTL_TEST_LOG"

            printf '%s\n' in-progress > "$latest/result"
            homelab-appctl deploy deopjib dev --target "$target"
            [ "$(grep -c '^systemctl[[:space:]]restart' "$HOMELAB_APPCTL_TEST_LOG")" -eq 2 ]

            jq '.caddyUrl = "http://127.0.0.1:19999"' "$metadata_root/deopjib/dev.json" > metadata.json
            mv metadata.json "$metadata_root/deopjib/dev.json"
            homelab-appctl deploy deopjib dev --target "$target"
            [ "$(grep -c '^systemctl[[:space:]]restart' "$HOMELAB_APPCTL_TEST_LOG")" -eq 3 ]

            previous_backend=$(cat "$image_state/backend")
            previous_web=$(cat "$image_state/web")
            if HOMELAB_APPCTL_TEST_FAIL_MIGRATION=1 \
              homelab-appctl deploy deopjib dev --target deopjib-v1.0.1; then
              echo 'migration failure unexpectedly succeeded' >&2
              exit 1
            fi
            [ "$(cat "$latest/result")" = migration-failed ]
            [ "$(cat "$image_state/backend")" = "$previous_backend" ]
            [ "$(cat "$image_state/web")" = "$previous_web" ]

            rm -f "$HOMELAB_APPCTL_TEST_FAIL_MARKER"
            if HOMELAB_APPCTL_TEST_FAIL_MIGRATION=1 HOMELAB_APPCTL_TEST_FAIL_RESTORE=1 \
              homelab-appctl deploy deopjib dev --target deopjib-v1.0.2; then
              echo 'recovery failure unexpectedly succeeded' >&2
              exit 1
            fi
            [ "$(cat "$latest/result")" = migration-recovery-failed ]

            rm -f "$HOMELAB_APPCTL_TEST_FAIL_MARKER"
            HOMELAB_APPCTL_TEST_FAIL_MIGRATION=0 HOMELAB_APPCTL_TEST_FAIL_RESTORE=0 \
              homelab-appctl deploy deopjib dev --target deopjib-v1.0.3 &
            first_pid=$!
            HOMELAB_APPCTL_TEST_FAIL_MIGRATION=0 HOMELAB_APPCTL_TEST_FAIL_RESTORE=0 \
              homelab-appctl deploy deopjib dev --target deopjib-v1.0.4 &
            second_pid=$!
            wait "$first_pid"
            wait "$second_pid"

            awk '
              /^restart-begin/ { if (active) exit 1; active = 1 }
              /^restart-end/ { if (!active) exit 1; active = 0 }
              END { if (active) exit 1 }
            ' "$HOMELAB_APPCTL_TEST_LOG"

            cp "$HOMELAB_APPCTL_TEST_LOG" "$out"
          '';

      homelabQuadletLifecycleInvariants =
        let
          homelab = self.nixosConfigurations.homelab_hj.config;
          quadlet = homelab.virtualisation.quadlet;
          hindsightDbContainerText = homelab.environment.etc."containers/systemd/hindsight-db.container".text;
          hindsightDbVolumeText = homelab.environment.etc."containers/systemd/hindsight-db-data.volume".text;
          hindsightNetwork = quadlet.networks.hindsight-db;
          network = homelab.virtualisation.quadlet.networks.deopjib-dev;
          networkService = "deopjib-dev-network.service";
          dnsLifecycleService = "podman-dns-lifecycle.service";
          dnsLifecycleConfig = homelab.homelab.podmanDnsLifecycle;
          dnsLifecycleUnit = homelab.systemd.services.podman-dns-lifecycle;
          expectedDnsLifecycleMembers = [
            "deopjib-dev-backend.service"
            "deopjib-dev-db.service"
            "deopjib-dev-network.service"
            "deopjib-dev-web.service"
            "hindsight-db-network.service"
            "hindsight-db.service"
            "hindsight.service"
          ];
          hindsightUnits = [
            homelab.systemd.services.hindsight-db
            homelab.systemd.services.hindsight
          ];
          podman = homelab.virtualisation.podman.package;
          pkgs = pkgsFor "x86_64-linux";
          backendContainer = quadlet.containers.deopjib-dev-backend;
          dbContainer = quadlet.containers.deopjib-dev-db;
          deopjibImages = lib.filterAttrs (name: _: lib.hasPrefix "deopjib-dev-" name) quadlet.images;
          networkText = builtins.unsafeDiscardStringContext network._configText;
          podmanPath = builtins.unsafeDiscardStringContext "${podman}";
          deopjibContainers = builtins.attrValues (
            lib.filterAttrs (name: _: lib.hasPrefix "deopjib-dev-" name) quadlet.containers
          );
          quadletObjects = [
            network
            hindsightNetwork
          ]
          ++ builtins.attrValues (
            lib.filterAttrs (name: _: lib.hasPrefix "deopjib-dev-" name) quadlet.volumes
          )
          ++ builtins.attrValues (lib.filterAttrs (name: _: lib.hasPrefix "deopjib-dev-" name) quadlet.images)
          ++ deopjibContainers
          ++ [
            {
              ref = "hindsight-db-data.volume";
              _configText = hindsightDbVolumeText;
            }
            {
              ref = "hindsight-db.container";
              _configText = hindsightDbContainerText;
            }
          ];
          quadletSources = pkgs.linkFarm "deopjib-dev-quadlets" (
            map (object: {
              name = object.ref;
              path = pkgs.writeText object.ref object._configText;
            }) quadletObjects
          );
        in
        assert network.networkConfig.name == "deopjib-dev";
        assert network.networkConfig.interfaceName == "br-deopjib-dev";
        assert builtins.elem 53 homelab.networking.firewall.interfaces.br-deopjib-dev.allowedUDPPorts;
        assert builtins.attrNames deopjibImages == [ "deopjib-dev-db" ];
        assert backendContainer.containerConfig.image == "ghcr.io/rjcnd105/deopjib-backend:dev-current";
        assert backendContainer.containerConfig.pull == "never";
        assert builtins.elem "deopjib-dev-db.service" backendContainer.unitConfig.Requires;
        assert builtins.elem "deopjib-dev-db.service" backendContainer.unitConfig.After;
        assert dbContainer.containerConfig.notify == "healthy";
        assert dbContainer.containerConfig.healthInterval == "1s";
        assert dbContainer.containerConfig.healthRetries == 30;
        assert dbContainer.containerConfig.healthTimeout == "5s";
        assert builtins.all (
          container:
          builtins.elem networkService container.unitConfig.PartOf
          && builtins.elem dnsLifecycleService container.unitConfig.PartOf
        ) deopjibContainers;
        assert builtins.elem dnsLifecycleService network.unitConfig.PartOf;
        assert hindsightNetwork.networkConfig.disableDns;
        assert builtins.elem dnsLifecycleService hindsightNetwork.unitConfig.PartOf;
        assert lib.hasInfix "Network=${hindsightNetwork.ref}" hindsightDbContainerText;
        assert lib.hasInfix "${podmanPath}/bin/podman network rm deopjib-dev" networkText;
        assert dnsLifecycleConfig.unit == dnsLifecycleService;
        assert lib.sort builtins.lessThan dnsLifecycleConfig.members == expectedDnsLifecycleMembers;
        assert builtins.elem podman dnsLifecycleUnit.restartTriggers;
        assert builtins.length dnsLifecycleUnit.restartTriggers == 2;
        assert builtins.all (
          unit: unit.overrideStrategy == "asDropin" && builtins.elem dnsLifecycleService unit.partOf
        ) hindsightUnits;
        assert !(homelab.system.activationScripts ? homelabAppContainersRefresh);
        pkgs.runCommand "homelab-quadlet-lifecycle-invariants" { } ''
          export QUADLET_UNIT_DIRS=${quadletSources}
          ${podman}/libexec/podman/quadlet -dryrun -no-kmsg-log > generated-units.txt

          ${pkgs.gnugrep}/bin/grep -F 'PartOf=${networkService}' generated-units.txt >/dev/null
          ${pkgs.gnugrep}/bin/grep -F '${dnsLifecycleService}' generated-units.txt >/dev/null
          ${pkgs.gnugrep}/bin/grep -F 'Requires=${networkService}' generated-units.txt >/dev/null
          ${pkgs.gnugrep}/bin/grep -F 'After=${networkService}' generated-units.txt >/dev/null
          ${pkgs.gnugrep}/bin/grep -F 'Requires=deopjib-dev-db.service' generated-units.txt >/dev/null
          ${pkgs.gnugrep}/bin/grep -F 'Notify=healthy' generated-units.txt >/dev/null
          ${pkgs.gnugrep}/bin/grep -F 'HealthInterval=1s' generated-units.txt >/dev/null
          ${pkgs.gnugrep}/bin/grep -F 'ExecStop=${podman}/bin/podman network rm deopjib-dev' generated-units.txt >/dev/null
          ${pkgs.gnugrep}/bin/grep -F -- '--interface-name br-deopjib-dev' generated-units.txt >/dev/null
          ${pkgs.gnugrep}/bin/grep -F -- '--disable-dns hindsight-db' generated-units.txt >/dev/null
          ${pkgs.gnugrep}/bin/grep -F 'Requires=hindsight-db-network.service' generated-units.txt >/dev/null

          mkdir -p "$out"
          cp generated-units.txt "$out/"
        '';

      homelabHindsightRuntimeInvariants =
        system:
        let
          pkgs = pkgsFor system;
        in
        pkgs.runCommand "homelab-hindsight-runtime-invariants" { } ''
          stack=${./systems/homelab/hindsight-stack.nix}

          ${pkgs.gnugrep}/bin/grep -F 'hindsight = "ghcr.io/vectorize-io/hindsight:latest-slim@sha256:9873b311f77a3e25813cadd14ccb10d730583aeb9d2c6e2107350e00c7af12bf";' "$stack" >/dev/null
          ${pkgs.gnugrep}/bin/grep -F 'Environment=HINDSIGHT_API_DB_STATEMENT_TIMEOUT=120' "$stack" >/dev/null
          ${pkgs.gnugrep}/bin/grep -F 'Environment=HINDSIGHT_API_ENABLE_AUTO_CONSOLIDATION=false' "$stack" >/dev/null
          ${pkgs.gnugrep}/bin/grep -F 'Environment=HINDSIGHT_API_WORKER_MAX_SLOTS=1' "$stack" >/dev/null
          ${pkgs.gnugrep}/bin/grep -F 'Environment=HINDSIGHT_API_WORKER_RETAIN_MAX_SLOTS=1' "$stack" >/dev/null
          ${pkgs.gnugrep}/bin/grep -F 'Environment=HINDSIGHT_API_WORKER_CONSOLIDATION_MAX_SLOTS=0' "$stack" >/dev/null
          if ${pkgs.gnugrep}/bin/grep -F 'HINDSIGHT_API_LAZY_RERANKER' "$stack" >/dev/null; then
            echo 'Hindsight v0.8 removed HINDSIGHT_API_LAZY_RERANKER; keep reranker init on the upstream eager path' >&2
            exit 1
          fi

          touch "$out"
        '';

      homelabThermalAlertSmoke =
        system:
        let
          pkgs = pkgsFor system;
          thermalAlert = pkgs.writeShellApplication {
            name = "homelab-thermal-alert";
            runtimeInputs = [
              pkgs.coreutils
              pkgs.curl
              pkgs.gawk
            ];
            text = builtins.readFile ./systems/homelab/thermal-alert.sh;
          };
        in
        pkgs.runCommand "homelab-thermal-alert-smoke" { } ''
          set -eu

          export PATH=${pkgs.coreutils}/bin:${pkgs.gnugrep}/bin:$PATH

          work="$TMPDIR/work"
          mkdir -p "$work"/{credentials,hwmon/hwmon0,proc/sys/kernel,state,runtime,bin}
          printf '%s' test-token > "$work/credentials/telegram-bot-token"
          printf '%s' 123456 > "$work/credentials/telegram-chat-id"
          printf '%s\n' homelab > "$work/proc/sys/kernel/hostname"
          printf '%s\n' '1.00 0.50 0.25 1/100 1000' > "$work/proc/loadavg"

          printf '%s\n' \
            '#!${pkgs.runtimeShell}' \
            'printf "%s\n" "99.0 postgres"' \
            > "$work/bin/ps"
          chmod +x "$work/bin/ps"

          printf '%s\n' \
            '#!${pkgs.runtimeShell}' \
            'set -eu' \
            'cat > "$CURL_STDIN_LOG"' \
            'printf "%s\n" "$@" >> "$CURL_ARGV_LOG"' \
            'output=' \
            'while [ "$#" -gt 0 ]; do' \
            '  case "$1" in' \
            '    --output)' \
            '      shift' \
            '      output="$1"' \
            '      ;;' \
            '  esac' \
            '  shift || true' \
            'done' \
            'if [ -n "$output" ]; then' \
            '  printf "%s\n" "{\"ok\":true}" > "$output"' \
            'fi' \
            'printf "%s" "''${CURL_HTTP_CODE:-200}"' \
            > "$work/bin/curl"
          chmod +x "$work/bin/curl"

          run_alert() {
            CREDENTIALS_DIRECTORY="$work/credentials" \
            HWMON_ROOT="$work/hwmon" \
            PROC_ROOT="$work/proc" \
            STATE_DIRECTORY="$work/state" \
            RUNTIME_DIRECTORY="$work/runtime" \
            CURL_BIN="$work/bin/curl" \
            PS_BIN="$work/bin/ps" \
            NOW_EPOCH="$1" \
              ${thermalAlert}/bin/homelab-thermal-alert
          }

          set_sensor() {
            printf '%s\n' k10temp > "$work/hwmon/hwmon0/name"
            printf '%s\n' Tctl > "$work/hwmon/hwmon0/temp1_label"
            printf '%s\n' "$1" > "$work/hwmon/hwmon0/temp1_input"
          }

          rm -f "$work/curl-argv.log" "$work/curl-stdin.log"
          export CURL_ARGV_LOG="$work/curl-argv.log"
          export CURL_STDIN_LOG="$work/curl-stdin.log"

          set_sensor 84999
          run_alert 2000
          if [ -e "$CURL_ARGV_LOG" ]; then
            echo "below-threshold run must not call curl" >&2
            exit 1
          fi

          set_sensor 85000
          run_alert 2000
          grep -F -- '--data-urlencode' "$CURL_ARGV_LOG" >/dev/null
          if grep -F 'test-token' "$CURL_ARGV_LOG" >/dev/null || grep -F '123456' "$CURL_ARGV_LOG" >/dev/null; then
            echo "Telegram credentials must not appear in curl argv" >&2
            exit 1
          fi
          grep -F 'test-token' "$CURL_STDIN_LOG" >/dev/null
          test "$(cat "$work/state/last-alert-epoch")" = 2000

          cp "$CURL_ARGV_LOG" "$work/curl-argv.first"
          run_alert 2100
          cmp "$work/curl-argv.first" "$CURL_ARGV_LOG"

          rm -f "$work/hwmon/hwmon0/name" "$work/hwmon/hwmon0/temp1_label" "$work/hwmon/hwmon0/temp1_input"
          if run_alert 4000 2>"$work/no-sensor.err"; then
            echo "missing k10temp sensor must fail the unit" >&2
            exit 1
          fi
          grep -F 'no k10temp CPU sensor found' "$work/no-sensor.err" >/dev/null

          touch "$out"
        '';
    in
    {
      _debug = { };

      formatter = eachSystem (system: treefmtEval.${system}.config.build.wrapper);

      checks =
        let
          baseChecks = eachSystem (system: {
            formatting = treefmtEval.${system}.config.build.check self;
            homelab-appctl-deploy-invariants = homelabAppctlDeployInvariants system;
            homelab-hindsight-runtime-invariants = homelabHindsightRuntimeInvariants system;
            homelab-thermal-alert-smoke = homelabThermalAlertSmoke system;
          });
        in
        lib.recursiveUpdate baseChecks {
          x86_64-linux.homelab-appctl-release-dry-run = homelabAppctlReleaseDryRun;
          x86_64-linux.homelab-appctl-release-transaction = homelabAppctlReleaseTransaction;
          x86_64-linux.homelab-quadlet-lifecycle-invariants = homelabQuadletLifecycleInvariants;
        };

      darwinConfigurations = lib.mapAttrs (
        key: config:
        let
          parsed = parseHostKey key config;
          inherit (parsed) hostName userName myOptions;
          systemModulePaths = getModulePaths "systems" config.system hostName userName;
          homeModulePaths = getModulePaths "homes" config.system hostName userName;
        in
        darwin.lib.darwinSystem {
          system = config.system;
          specialArgs = {
            inherit inputs myOptions;
          };
          modules = [
            { nixpkgs = nixpkgsConfig config.system; }
            home-manager.darwinModules.home-manager
            { home-manager.users.${userName}.imports = homeModulePaths; }
          ]
          ++ systemModulePaths;
        }
      ) darwinHosts;

      nixosConfigurations = lib.mapAttrs (
        key: config:
        let
          parsed = parseHostKey key config;
          inherit (parsed) hostName userName myOptions;
          systemModulePaths = getModulePaths "systems" config.system hostName userName;
          homeModulePaths = getModulePaths "homes" config.system hostName userName;
        in
        nixpkgs.lib.nixosSystem {
          system = config.system;
          specialArgs = {
            inherit inputs myOptions;
          };
          modules = [
            { nixpkgs = nixpkgsConfig config.system; }
            { system.configurationRevision = self.rev or self.dirtyRev or "dirty"; }
            home-manager.nixosModules.home-manager
            { home-manager.users.${userName}.imports = homeModulePaths; }
            comin.nixosModules.comin
            quadlet-nix.nixosModules.quadlet
          ]
          ++ systemModulePaths;
        }
      ) linuxHosts;

      devShells = eachSystem (
        system:
        let
          pkgs = pkgsFor system;
        in
        {
          default = pkgs.mkShell {
            packages = [
              pkgs.nixd
              treefmtEval.${system}.config.build.wrapper
            ];
          };
        }
      );
    };
}
