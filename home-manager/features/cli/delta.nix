# https://github.com/dandavison/delta
{
  programs.delta = {
    enable = true;
  };

  programs.git = {
    delta = {  # git diff 강화
        enable = true;
        options = {
            navigate = true;
            light = false;
            side-by-side = true;
        };
    };
  };
}
