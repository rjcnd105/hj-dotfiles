{ pkgs, ... }:
{
  home.packages = with pkgs; [
    just
    difftastic
    lazydocker
    ffmpeg
    pandoc
    mkcert
    dive
  ];
}
