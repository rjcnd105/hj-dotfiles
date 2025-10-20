{
  inputs,
  pkgs,
  myOptions,
  ...
}:
{
  programs.delta = {
    enable = true;
  };
  programs.git = {
    enable = true;

    settings = {
      user = {
        name = myOptions.userName;
        email = myOptions.email;
      };
      core = {
        quotePath = false;
        precomposeunicode = true;
      };
      push = {
        autoSetupRemote = true;
      };
    };

    signing = {
      format = "openpgp";
    };

    ignores = [
      ".DS_Store"
      "*.swp"
    ];

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
