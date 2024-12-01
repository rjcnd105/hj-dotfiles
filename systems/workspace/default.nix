{ config, inputs, ... }:
{
  config = {
    imports = [
      inputs.nix-index-database.darwinModules.nix-index
      inputs.determinate.darwinModules.default
    ];

    environment.systemPackages = [ inputs.comma ];
  };
}
