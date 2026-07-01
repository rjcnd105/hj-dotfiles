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

    deopjibRuntime = {
      url = "github:rjcnd105/my-app/feat/deopjib-runtime-contract";
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

      homelabAppctlDeployInvariants =
        system:
        let
          pkgs = pkgsFor system;
        in
        pkgs.runCommand "homelab-appctl-deploy-invariants" { } ''
          app_containers=${./systems/homelab/app-containers.nix}

          ${pkgs.gnugrep}/bin/grep -F 'systemctl restart "$image_unit"' "$app_containers" >/dev/null
          if ${pkgs.gnugrep}/bin/grep -F 'systemctl start "$image_unit"' "$app_containers" >/dev/null; then
            echo 'homelab-appctl deploy must restart image pull units; start is a no-op for active oneshot .image units' >&2
            exit 1
          fi

          touch "$out"
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
        baseChecks;

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
