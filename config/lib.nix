# config/options.nix
{ lib, pkgs, ... }:
let
  projectRoot = ./..;
  pwd = builtins.getEnv "PWD";
in
rec {
  options = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = { };
    description = "Global custom configuration";
  };
  config = {
    paths = {
      root = projectRoot;
      pkgs = projectRoot + "/pkgs";
      files = projectRoot + "/files";
      homes = projectRoot + "/homes";
      sharedHome = projectRoot + "/sharedHome";
      hosts = projectRoot + "/hosts";
    };
  };
}
