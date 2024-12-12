# config/options.nix
{ lib, ... }:
let
  projectRoot = toString ./..;
  getHostEnvPath = hostName: "${projectRoot}/hosts/${hostName}";
in
{
  options = lib.mkOption {
    type = lib.types.attrsOf lib.types.anything;
    default = { };
    description = "Global custom configuration";
  };
  config = {
    fn = {
      getHostEnvPath = hostName: "${projectRoot}/hosts/${hostName}";
    };
    paths = {
      root = projectRoot;
      homes = projectRoot + "/homes";
      sharedHome = projectRoot + "/sharedHome";
      hosts = projectRoot + "/hosts";
    };
  };
}
