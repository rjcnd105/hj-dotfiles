{ pkgs, customConfig, ... }:
{
  programs.git = {
    enable = true;
    userEmail = customConfig.email;
    userName = customConfig.userName;

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

  home.shellAliases = {
    g = "git";
    gc = "git commit";
    gs = "git status";
    gd = "git diff";
    gdc = "git diff --cached";
    ga = "git add . -p";
    gp = "git push";
  };

}