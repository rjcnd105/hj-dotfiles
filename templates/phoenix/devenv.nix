{
  pkgs,
  lib,
  inputs,
  ...
}:
let

  pkgs-unstable = import inputs.nixpkgs-unstable { system = pkgs.stdenv.system; };
  # Install Phoenix dependencies:

in
# mix local.hex
# mix local.rebar
# mix archive.install hex phx_new
#
# Follow the instructions from https://hexdocs.pm/phoenix/up_and_running.html
# Run `mix phx.new hello --install` to create a new Phoenix project
{
  packages = [
    pkgs.git
  ] ++ lib.optionals pkgs.stdenv.isLinux [ pkgs.inotify-tools ];

  languages.elixir.enable = true;
  dotenv.enable = true;

  services.postgres = {
    enable = true;
    initialScript = ''
      CREATE ROLE postgres WITH LOGIN PASSWORD 'postgres' SUPERUSER;
    '';
    initialDatabases = [ { name = "mypg"; } ];
    package = pkgs-unstable.postgresql_17;
  };

  processes.phoenix.exec = "cd hello && mix phx.server";
}
