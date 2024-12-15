# config/options.nix
{ lib, ... }:
let
  projectRoot = ./..;
in
{
  options = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = { };
    description = "Global custom configuration";
  };
  config = {
    paths = {
      root = projectRoot;
      files = projectRoot + "/files";
      homes = projectRoot + "/homes";
      sharedHome = projectRoot + "/sharedHome";
      hosts = projectRoot + "/hosts";
    };
  };
}
