{ ... }:
{
  programs.gh = {
    enable = true;
    settings = {
      prompt = "enabled";
    };
  };

  home.shellAliases = {
    prw = "gh pr view --web";
  };
}
