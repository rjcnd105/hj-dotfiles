{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devenv.url = "github:cachix/devenv";
    mise = {
      url = "github:jdx/mise/release";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs =
    inputs@{
      flake-parts,
      nixpkgs,
      mise,
      ...
    }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.flake-parts.flakeModules.easyOverlay
        inputs.devenv.flakeModule
      ];
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      debug = true;

      perSystem =
        {
          system,
          lib,
          config,
          ...
        }:
        let
          overlayedPkgs = import nixpkgs {
            system = system;
            overlays = [
              (final: prev: {
                mise = prev.callPackage (mise + "/default.nix") { };
              })
            ];
            config = {
              allowUnfreePredicate =
                pkg:
                builtins.elem (lib.getName pkg) [
                  "timescaledb"
                ];
            };
          };
        in
        {
          _module.args.pkgs = overlayedPkgs;

          devenv.shells.default =
            {
              config,
              lib,
              pkgs,
              ...
            }:
            let
              inherit (config.env) APP_NAME DB_NAME;
            in
            {

              dotenv = {
                enable = true;
                filename = [
                  ".env.dev"
                ];
              };

              env.MISE_GLOBAL_CONFIG = false;
              env.MISE_DEFAULT_TOOL_VERSIONS_FILENAME = ".mise.toml";

              # services
              services.postgres = {
                enable = true;
                initialScript = ''
                  CREATE ROLE postgres WITH LOGIN PASSWORD 'postgres' SUPERUSER;
                '';
                initialDatabases = [ { name = config.env.APP_NAME; } ];
                extensions = extensions: [
                  extensions.postgis
                  extensions.timescaledb
                ];
                initdbArgs = [
                  "--locale=ko_KR.UTF-8"
                  "--encoding=UTF8"
                ];
                package = pkgs.postgresql_17;
              };

              services.caddy = {
                enable = true;
                package = pkgs.caddy;
              };

              # services.opentelemetry-collector = {
              #   enable = true;
              #   package = pkgs.opentelemetry-collector-contrib;
              # };

              processes.phoenix.exec = "cd hello && mix phx.server";

              tasks."myapp:hello" = {
                exec = ''echo "Hello, world!"'';
                before = [
                  "devenv:enterShell"
                  "devenv:enterTest"
                ];
              };

              packages =
                [
                  # https://devenv.sh/reference/options/
                  pkgs.mise
                ]
                ++ lib.optionals pkgs.stdenv.isLinux [
                  pkgs.inotify-tools
                ]
                ++ lib.optionals (!config.container.isBuilding) [
                ];

              scripts = {
                "mise-init" = {
                  exec = ''
                    mise trust ./.
                    mise install
                    mise activate -q
                  '';
                };
                "env-info" = {
                  exec = ''
                    echo your system: ${system}
                    echo your app: ${APP_NAME}
                    echo your DB_NAME: ${DB_NAME}
                  '';
                };
              };

              enterShell = ''
                echo hello
              '';

            };
        };
    };
}
