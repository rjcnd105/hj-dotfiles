# config/options.nix
{ lib, ... }:
{
  options.customConfig = lib.mkOption {
    type = lib.types.attrs;
    default = { };
    description = "Global custom configuration";
  };
}
