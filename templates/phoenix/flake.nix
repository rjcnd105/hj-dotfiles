{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    flake-parts.url = "github:hercules-ci/flake-parts";
    process-compose-flake.url = "github:Platonic-Systems/process-compose-flake";
    services-flake.url = "github:juspay/services-flake";
  };
  outputs =
    inputs@{
      self,
      nixpkgs,
      flake-parts,
      ...
    }:
    let

      unquote = s: builtins.replaceStrings [ "\"" ] [ "" ] s;
      devEnv = {
        DB_HOST = unquote (builtins.getEnv "DB_HOST");
        DB_PORT = unquote (builtins.getEnv "DB_PORT");
        DB_LISTEN_ADDRESSES = unquote (builtins.getEnv "DB_LISTEN_ADDRESSES");
        DB_NAME = unquote (builtins.getEnv "DB_NAME");
        DB_USER = unquote (builtins.getEnv "DB_USER");
        DB_PASSWORD = unquote (builtins.getEnv "DB_PASSWORD");
      };

    in

    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [
        inputs.process-compose-flake.flakeModule
      ];
      systems = [
        "aarch64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      debug = true;

      perSystem =
        {
          self',
          system,
          lib,
          config,
          ...
        }:
        let
          pkgs = import nixpkgs {
            system = system;
            config = {
              allowUnfreePredicate =
                pkg:
                builtins.elem (lib.getName pkg) [
                  "timescaledb"
                ];
            };
          };
          commonPackages =
            [ ]
            ++ lib.optionals pkgs.stdenv.isLinux [
              pkgs.inotify-tools
            ];

        in
        # str = lib.concatStringsSep "\n" (lib.mapAttrsToList (n: v: "export ${n}=${v}") devEnv);
        {
          _module.args.pkgs = pkgs;

          process-compose."app-services" =
            let
              _DB_HOST = devEnv.DB_HOST;
              DB_PORT = lib.strings.toIntBase10 devEnv.DB_PORT;
              DB_LISTEN_ADDRESSES = devEnv.DB_LISTEN_ADDRESSES;
              DB_NAME = devEnv.DB_NAME;
              DB_USER = devEnv.DB_USER;
              DB_PASSWORD = devEnv.DB_PASSWORD;
            in
            { config, lib, ... }:
            {
              imports = [
                inputs.services-flake.processComposeModules.default
              ];
              services = {
                postgres."pg" = {
                  enable = true;
                  package = pkgs.postgresql_18;
                  listen_addresses = DB_LISTEN_ADDRESSES;
                  dataDir = "./data/pg";
                  port = DB_PORT;
                  initialScript = {
                    before = ''
                      CREATE ROLE ${DB_USER} WITH LOGIN PASSWORD '${DB_PASSWORD}' SUPERUSER;
                      CREATE DATABASE ${DB_NAME};
                    '';
                  };
                };

              };
              settings.processes.pgweb =
                let
                  pgcfg = config.services.postgres.pg;
                in
                {
                  command = pkgs.pgweb;
                  depends_on."pg".condition = "process_healthy";
                  environment.PGWEB_DATABASE_URL = pgcfg.connectionURI {
                    dbName = DB_NAME;
                  };
                };
            };

          devShells.default = pkgs.mkShell {
            packages = [ ] ++ commonPackages;
            inputsFrom = [
              config.process-compose."app-services".services.outputs.devShell
            ];
          };

        };
    };
}
