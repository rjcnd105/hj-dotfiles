{
  pkgs,
  lib,
  inputs,
  self',
  ...
}:
{
  dotenv = {
    enable = true;
    filename = [
      "./.env.flake"
    ];
  };

  packages = [ ] ++ lib.optionals pkgs.stdenv.isLinux [ pkgs.inotify-tools ];

  # services
  services.postgres = {
    enable = true;
    initialScript = ''
      CREATE ROLE postgres WITH LOGIN PASSWORD 'postgres' SUPERUSER;
    '';
    initialDatabases = [ { name = "mypg"; } ];
    package = pkgs.postgresql_17;
  };

  services.caddy = {
    enable = true;
    package = pkgs.caddy;

  };

  processes.phoenix.exec = "cd hello && mix phx.server";

  entherShell = ''
    mise activate
  '';
}
