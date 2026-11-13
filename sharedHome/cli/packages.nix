{ pkgs, ... }:
{
  home.packages = with pkgs; [
    difftastic
    lazydocker
    ffmpeg
    pandoc
    mkcert
    dive
  ];
}
