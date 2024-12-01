{
  pkgs,
  host,
  config,
  inputs,
  catppuccin,
  nixvim,
  ...
}:
{

  system.stateVersion = 5;

  networking = {
    hostName = host.user;
    computerName = host.user;
    localHostName = host.user;
  };

  environment = {
    shells = [
      pkgs.bash
      pkgs.fish
    ];
    systemPackages = [
      pkgs.nixfmt-rfc-style
      pkgs.nixd
    ];
    variables = {
      EDITOR = "nvim";
      VISUAL = "zed";
      PAGER = "less";
      LESS = "-R";
      LANG = "ko_KR.UTF-8";
    };
  };

  home-manager = {
    extraSpecialArgs = {
      envVars = config.environment.variables;
    };
  };

  nix = {
    nixPath = [ "nixpkgs=${inputs.nixpkgs}" ];
    settings = {
      trusted-users = [
        "root"
        host.user
      ];
      keep-derivations = true;
      keep-outputs = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };

    configureBuildUsers = true;
    optimise.automatic = true;

    # garbage collection
    gc = {
      automatic = true;
      options = "--delete-older-than 45d";
    };
  };
}
