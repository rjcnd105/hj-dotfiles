# config/options.nix
{ lib, ... }:
let
  projectRoot = toString ./..; # 상위 디렉토리 참조
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
      custom = projectRoot + "/config/options.nix";
    };
  };
}
