{ inputs, customConfig, ... }:
{
  home.packages = [
    inputs.nixvim_dc-tec.packages.${customConfig.system}.default
  ];
}
