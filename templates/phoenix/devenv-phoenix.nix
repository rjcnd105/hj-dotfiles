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
      ".env.flake"
    ];
  };

  # services
  services.postgres = {
    enable = true;
    initialScript = ''
      CREATE ROLE postgres WITH LOGIN PASSWORD 'postgres' SUPERUSER;
    '';
    initialDatabases = [ { name = "mypg"; } ];

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
  processes.phoenix.exec = "cd hello && mix phx.server";

}
