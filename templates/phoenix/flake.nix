{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    devenv.url = "github:cachix/devenv";
    mise = {
      url = "github:jdx/mise/main";
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
              envJson = builtins.toJSON {
                inherit (config.env)
                  DEVENV_ROOT
                  PGHOST
                  PGDATA
                  PGPORT
                  PROJECT_NAME
                  ;
              };
              umbrellaProjectName = "${config.env.PROJECT_NAME}_umbrella";
            in
            {

              dotenv = {
                enable = true;
                filename = [
                  ".env.root"
                ];
              };

              env.MISE_GLOBAL_CONFIG = false;

              # services
              services.postgres = {
                enable = true;
                initialScript = ''
                  CREATE ROLE postgres WITH LOGIN PASSWORD 'postgres' SUPERUSER;
                '';
                extensions = extensions: [
                  extensions.pg_cron
                  extensions.postgis
                  extensions.timescaledb
                ];
                initdbArgs = [
                  "--locale=ko_KR.UTF-8"
                  "--encoding=UTF8"
                ];
                listen_addresses = "*";
                port = 5432;
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

              processes.phoenix.exec = "cd ${umbrellaProjectName} && mix phx.server";

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
                    echo env
                    echo ${envJson} | tr " " "\n"
                  '';
                };
                "update-env" = {
                  exec = ''
                    # .env.root 파일 처리
                    ENV_FILE=".env.root"
                    NEW_PROJECT_NAME=$1

                    if [ -f $ENV_FILE ]; then
                      # PROJECT_NAME이 있는지 확인
                      if awk -F= '/^PROJECT_NAME=/ {found=1; exit} END{exit !found}' $ENV_FILE; then
                        # PROJECT_NAME이 있으면 교체
                        awk -i inplace '/^PROJECT_NAME=/{print "PROJECT_NAME='$NEW_PROJECT_NAME'";next}{print}' .env.root
                        echo "Updated PROJECT_NAME in $ENV_FILE"
                      else
                        # PROJECT_NAME이 없으면 추가
                        echo "PROJECT_NAME=NEW_PROJECT_NAME" >> $ENV_FILE
                        echo "Added PROJECT_NAME to $ENV_FILE"
                      fi
                    else
                      echo "PROJECT_NAME=$NEW_PROJECT_NAME" > $ENV_FILE
                      echo "Created .env.root with PROJECT_NAME"
                    fi
                  '';
                };
                # mix archive.install hex phx_new
                "app-init" = {
                  exec = ''
                    PROJECT_NAME=$1
                    APP_NAME=$2

                    if [ -z "$PROJECT_NAME" ] && [ -z "$APP_NAME" ]; then
                        echo "Error: ProjectName and AppName is required"
                        exit 1
                    fi

                    update-env $PROJECT_NAME
                    mix phx.new --umbrella --database=postgres --app=$APP_NAME $PROJECT_NAME

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
