{
  config,
  pkgs,
  inputs,
  ...
}:
{
  imports = [
    inputs.nix-index-database.darwinModules.nix-index
    inputs.determinate.darwinModules.default
  ];
  config = {
    environment.systemPackages = [ inputs.comma ];
  };

}
