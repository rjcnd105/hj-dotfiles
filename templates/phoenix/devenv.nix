{
  pkgs,
  lib,
  inputs,
  ...
}:
let
  otp = beam.packages.erlang_27;
  elixir_1_18_rc_0 = otp.elixir_1_17.overrideAttrs (oldAttrs: {
    version = "1.18-rc.0";
    src = fetchFromGitHub {
      owner = "elixir-lang";
      repo = "elixir";
      rev = "66c5908619f2ee9b4b1113e0302b00b5a59a5abb";
      sha256 = "";
    };
  });
in
{
  packages = [
    opt
    elixir_1_18_rc_0
  ];

  dotenv.enable = true;
  languages.elixir.enable = true;
  languages.elixir.package = elixir_1_18_rc_0;

  services.postgres = {
    enable = true;
    initialScript = ''
      CREATE ROLE postgres WITH LOGIN PASSWORD 'postgres' SUPERUSER;
    '';
    initialDatabases = [ { name = "mypg"; } ];
    package = pkgs.postgresql_17;
  };

  processes.phoenix.exec = "cd hello && mix phx.server";
}
