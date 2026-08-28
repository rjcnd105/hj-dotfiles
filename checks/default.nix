# flake checks. flake.nix에서 분리된 픽스처·검증 정의.
#  - eval 단정(quadlet/contract-v2)은 --no-build에서도 실행된다.
#  - x86_64-linux 빌드 체크는 CI(Linux)에서 빌드된다.
{
  self,
  inputs,
  lib,
  pkgsFor,
  eachSystem,
  treefmtEval,
}:
let
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
      # v2 manifest는 jq로 직접 생성한다 (앱 레포 CI와 같은 방식; 전용 generator 없음).
      releaseManifest =
        pkgs.runCommand "deopjib-release-manifest-fixture"
          {
            nativeBuildInputs = [
              pkgs.check-jsonschema
              pkgs.jq
            ];
          }
          ''
            jq -n '{
              schemaVersion: 2,
              app: "deopjib",
              target: "deopjib-v0.0.0-dev.0000000",
              version: "0.0.0-dev.0000000",
              sourceRev: "0000000000000000000000000000000000000000",
              generatedAt: "2026-07-20T00:00:00Z",
              images: {
                backend: {
                  name: "ghcr.io/rjcnd105/deopjib-backend",
                  digest: "sha256:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
                },
                web: {
                  name: "ghcr.io/rjcnd105/deopjib-web",
                  digest: "sha256:bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
                }
              }
            }' > "$out"
            check-jsonschema \
              --schemafile ${inputs.deopjibRuntime}/deopjib/devops/release-manifest.schema.json \
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

  # sops 암호문은 값 타입을 평문 마커(type:int 등)로 노출한다. sops-install-secrets는
  # 문자열만 허용하므로 비문자열 타입은 다음 switch를 죽인다 — 복호화 없이 조기 검출.
  sopsSecretsAreStrings =
    system:
    let
      pkgs = pkgsFor system;
    in
    pkgs.runCommand "sops-secrets-are-strings" { } ''
      if ${pkgs.gnugrep}/bin/grep -rnE 'type:(int|bool|float)\]' ${../secrets}; then
        echo 'sops secrets must be strings: re-quote the offending value via sops set' >&2
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

        expect_rejected schema-version '.schemaVersion = 1'
        expect_rejected target '.target = "deopjib-v0.0.0-dev.1111111"'
        expect_rejected backend-name '.images.backend.name = "ghcr.io/rjcnd105/not-admitted"'
        expect_rejected backend-digest '.images.backend.digest = "sha256:not-a-digest"'
        expect_rejected missing-image 'del(.images.web)'

        cp dry-run.out "$out"
      '';

  homelabQuadletLifecycleInvariants =
    let
      homelab = self.nixosConfigurations.homelab_hj.config;
      quadlet = homelab.virtualisation.quadlet;
      network = homelab.virtualisation.quadlet.networks.deopjib-dev;
      networkService = "deopjib-dev-network.service";
      dnsLifecycleService = "podman-dns-lifecycle.service";
      dnsLifecycleConfig = homelab.homelab.podmanDnsLifecycle;
      dnsLifecycleUnit = homelab.systemd.services.podman-dns-lifecycle;
      expectedDnsLifecycleMembers = [
        "deopjib-dev-backend.service"
        "deopjib-dev-network.service"
        "deopjib-dev-web.service"
      ];
      podman = homelab.virtualisation.podman.package;
      pkgs = pkgsFor "x86_64-linux";
      backendContainer = quadlet.containers.deopjib-dev-backend;
      deopjibImages = lib.filterAttrs (name: _: lib.hasPrefix "deopjib-dev-" name) quadlet.images;
      networkText = builtins.unsafeDiscardStringContext network._configText;
      podmanPath = builtins.unsafeDiscardStringContext "${podman}";
      deopjibContainers = builtins.attrValues (
        lib.filterAttrs (name: _: lib.hasPrefix "deopjib-dev-" name) quadlet.containers
      );
      quadletObjects = [
        network
      ]
      ++ builtins.attrValues (
        lib.filterAttrs (name: _: lib.hasPrefix "deopjib-dev-" name) quadlet.volumes
      )
      ++ builtins.attrValues (lib.filterAttrs (name: _: lib.hasPrefix "deopjib-dev-" name) quadlet.images)
      ++ deopjibContainers;
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
    # v2: 컨테이너 db 없음 — 공유 호스트 PostgreSQL에 systemd 의존성으로 연결.
    assert builtins.attrNames deopjibImages == [ ];
    assert !(quadlet.containers ? deopjib-dev-db);
    assert backendContainer.containerConfig.image == "ghcr.io/rjcnd105/deopjib-backend:dev-current";
    assert backendContainer.containerConfig.pull == "never";
    assert builtins.elem "postgresql.service" backendContainer.unitConfig.Requires;
    assert builtins.elem "postgresql.service" backendContainer.unitConfig.After;
    assert builtins.elem "homelab-postgres-credentials.service" backendContainer.unitConfig.After;
    assert builtins.elem "deopjib_dev" homelab.services.postgresql.ensureDatabases;
    assert builtins.all (
      container:
      builtins.elem networkService container.unitConfig.PartOf
      && builtins.elem dnsLifecycleService container.unitConfig.PartOf
    ) deopjibContainers;
    assert builtins.elem dnsLifecycleService network.unitConfig.PartOf;
    assert lib.hasInfix "${podmanPath}/bin/podman network rm deopjib-dev" networkText;
    assert dnsLifecycleConfig.unit == dnsLifecycleService;
    assert lib.sort builtins.lessThan dnsLifecycleConfig.members == expectedDnsLifecycleMembers;
    assert builtins.elem podman dnsLifecycleUnit.restartTriggers;
    assert builtins.length dnsLifecycleUnit.restartTriggers == 2;
    assert !(homelab.system.activationScripts ? homelabAppContainersRefresh);
    pkgs.runCommand "homelab-quadlet-lifecycle-invariants" { } ''
      export QUADLET_UNIT_DIRS=${quadletSources}
      ${podman}/libexec/podman/quadlet -dryrun -no-kmsg-log > generated-units.txt

      ${pkgs.gnugrep}/bin/grep -F 'PartOf=${networkService}' generated-units.txt >/dev/null
      ${pkgs.gnugrep}/bin/grep -F '${dnsLifecycleService}' generated-units.txt >/dev/null
      ${pkgs.gnugrep}/bin/grep -F 'Requires=${networkService}' generated-units.txt >/dev/null
      ${pkgs.gnugrep}/bin/grep -F 'After=${networkService}' generated-units.txt >/dev/null
      ${pkgs.gnugrep}/bin/grep -F 'Requires=postgresql.service' generated-units.txt >/dev/null
      ${pkgs.gnugrep}/bin/grep -F 'After=homelab-postgres-credentials.service' generated-units.txt >/dev/null
      if ${pkgs.gnugrep}/bin/grep -F 'deopjib-dev-db' generated-units.txt >/dev/null; then
        echo 'v2 units must not reference the removed container database' >&2
        exit 1
      fi
      ${pkgs.gnugrep}/bin/grep -F 'ExecStop=${podman}/bin/podman network rm deopjib-dev' generated-units.txt >/dev/null
      ${pkgs.gnugrep}/bin/grep -F -- '--interface-name br-deopjib-dev' generated-units.txt >/dev/null

      mkdir -p "$out"
      cp generated-units.txt "$out/"
    '';

  homelabThermalAlertSmoke =
    system:
    let
      pkgs = pkgsFor system;
      thermalAlert = pkgs.callPackage ../systems/homelab/thermal-alert-package.nix { };
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

  # 계약 v2 렌더링 픽스처: example 앱(needs.postgres, PORT/데이터 컨벤션)을
  # 최소 NixOS 시스템으로 평가한다. 호스트에는 아무것도 배포되지 않는다.
  contractV2Fixture = inputs.nixpkgs.lib.nixosSystem {
    system = "x86_64-linux";
    specialArgs = {
      inherit inputs;
      myOptions.userName = "hj";
    };
    modules = [
      inputs.sops-nix.nixosModules.sops
      inputs.quadlet-nix.nixosModules.quadlet
      ../systems/homelab/app-containers.nix
      ../systems/homelab/postgres.nix
      ../systems/homelab/podman-dns-lifecycle.nix
      ./fixtures/fixture-host.nix
      {
        homelab.apps = import ../systems/homelab/admit-app.nix {
          admission = import ./fixtures/example/homelab-admission.nix;
          releaseManifestOrigins = [ "https://github.com/example/example" ];
          host = {
            subnetId = 7;
            postgresPasswordSecret = "EXAMPLE_DEV_PG_PASSWORD";
          };
        };
      }
    ];
  };

  homelabContractV2Invariants =
    let
      pkgs = pkgsFor "x86_64-linux";
      fixture = contractV2Fixture.config;
      envTemplate = fixture.sops.templates."example-dev-app.env".content;
      metadata = builtins.fromJSON fixture.environment.etc."homelab-apps/example/dev.json".text;
      network = fixture.virtualisation.quadlet.networks.example-dev;
      # toplevel 평가가 모듈 assertion까지 강제한다 (빌드는 하지 않는다).
      fixtureToplevel = builtins.unsafeDiscardStringContext fixture.system.build.toplevel.drvPath;
    in
    assert metadata.contractVersion == 2;
    assert !(metadata ? runtimeContractSourceSha256);
    assert !(metadata ? homelabAdmissionSourceSha256);
    assert lib.hasInfix "PORT=3000" envTemplate;
    assert lib.hasInfix "DATABASE_URL=postgresql://example_dev:" envTemplate;
    assert lib.hasInfix "@10.90.7.1:5432/example_dev" envTemplate;
    assert network.networkConfig.subnets == [ "10.90.7.0/24" ];
    assert network.networkConfig.gateways == [ "10.90.7.1" ];
    assert fixture.services.postgresql.enable;
    assert builtins.elem "example_dev" fixture.services.postgresql.ensureDatabases;
    assert lib.hasInfix "host example_dev example_dev 10.90.7.0/24 scram-sha-256"
      fixture.services.postgresql.authentication;
    assert builtins.elem 5432 fixture.networking.firewall.interfaces.br-example-dev.allowedTCPPorts;
    assert fixture.virtualisation.quadlet.containers ? example-dev-app;
    assert !(fixture.virtualisation.quadlet.containers ? example-dev-db);
    assert builtins.elem "postgresql.service"
      fixture.virtualisation.quadlet.containers.example-dev-app.unitConfig.Requires;
    assert builtins.elem "homelab-postgres-credentials.service"
      fixture.virtualisation.quadlet.containers.example-dev-app.unitConfig.After;
    pkgs.runCommand "homelab-contract-v2-invariants" { inherit fixtureToplevel; } ''
      touch "$out"
    '';

  # systemd 유닛의 ExecStart 실행 파일이 실제로 존재하는지 확인한다. Nix는 잘못된
  # 바이너리 이름을 store 경로 문자열로 그대로 통과시키고, 호스트에서 status=203/EXEC로
  # 터진다 (Phase 4 beszel `bin/beszel` vs `bin/beszel-hub`에서 실측).
  homelabUnitExecutablesExist =
    let
      pkgs = pkgsFor "x86_64-linux";
      homelab = self.nixosConfigurations.homelab_hj.config;
      # ExecStart는 문자열/문자열 목록이며 `-`, `@`, `+` 등 접두 문자가 붙을 수 있다.
      execPath =
        entry:
        builtins.head (
          lib.splitString " " (
            lib.removePrefix "+" (lib.removePrefix "@" (lib.removePrefix "-" (toString entry)))
          )
        );
      execStarts = lib.flatten (
        lib.mapAttrsToList (_name: unit: map execPath (lib.toList unit.serviceConfig.ExecStart)) (
          lib.filterAttrs (_: unit: (unit.serviceConfig.ExecStart or null) != null) homelab.systemd.services
        )
      );
      paths = lib.unique (builtins.filter (path: lib.hasPrefix builtins.storeDir path) execStarts);
    in
    pkgs.runCommand "homelab-unit-executables-exist" { inherit paths; } ''
      status=0
      for path in $paths; do
        if [ ! -x "$path" ]; then
          echo "ExecStart target is missing or not executable: $path" >&2
          status=1
        fi
      done
      [ "$status" -eq 0 ] || exit 1
      touch "$out"
    '';
in
lib.recursiveUpdate
  (eachSystem (system: {
    formatting = treefmtEval.${system}.config.build.check self;
    homelab-thermal-alert-smoke = homelabThermalAlertSmoke system;
    sops-secrets-are-strings = sopsSecretsAreStrings system;
  }))
  {
    # buildGoModule checkPhase가 단위 테스트 + 스텁 E2E 트랜잭션 테스트를 실행한다.
    x86_64-linux.homelab-appctl-package =
      (pkgsFor "x86_64-linux").callPackage ../packages/homelab-appctl/package.nix
        { };
    x86_64-linux.homelab-appctl-release-dry-run = homelabAppctlReleaseDryRun;
    x86_64-linux.homelab-quadlet-lifecycle-invariants = homelabQuadletLifecycleInvariants;
    x86_64-linux.homelab-contract-v2-invariants = homelabContractV2Invariants;
    x86_64-linux.homelab-unit-executables-exist = homelabUnitExecutablesExist;
  }
