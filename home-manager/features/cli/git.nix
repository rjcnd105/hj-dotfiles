{ pkgs, ... }:
{
  programs.git = {
    enable = true;
    userEmail = "rjcnd123@gmail.com";
    userName = "hj";

    aliases = {
      co = "checkout";
      br = "branch";
    };

    extraConfig = {
      core = {
        quotePath = false;
        precomposeunicode = true;
      };
      push = {
        autoSetupRemote = true;
      };
    };

    ignores = [
      ".DS_Store"
      "*.swp"
    ];

    delta.enable = true;
    lfs.enable = true;
  };

  programs.bash.shellAliases = {
    g = "git";
    gc = "git commit";
    gs = "git status";
    gd = "git diff";
    gdc = "git diff --cached";
    ga = "git add . -p";
    gp = "git push";
  };

  home.packages = [
    (pkgs.callPackage ../../../pkgs/gm.nix { })
  ];
}
