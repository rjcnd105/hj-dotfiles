{
  config,
  pkgs,
  customConfig,
  ...
}:
{
  config.users.users.${customConfig.userName} = {
    name = ${customConfig.userName};
    home = "/Users/${customConfig.userName}";
    shell = pkgs.fish;
  };
}
