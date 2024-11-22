{ config, pkgs, ... }:

{
  boot.kernelPackages = pkgs.linuxPackages_latest;
  time.timeZone = "Asia/Seoul";

  i18n.defaultLocale = "ko_KR.utf8";
  i18n.extraLocaleSettings = {
    LC_ADDRESS = "ko_KR.utf8";
    LC_IDENTIFICATION = "ko_KR.utf8";
    LC_MEASUREMENT = "ko_KR.utf8";
    LC_MONETARY = "ko_KR.utf8";
    LC_NAME = "ko_KR.utf8";
    LC_NUMERIC = "ko_KR.utf8";
    LC_PAPER = "ko_KR.utf8";
    LC_TELEPHONE = "ko_KR.utf8";
    LC_TIME = "ko_KR.utf8";
  };

  # coommon packages
  environment.systemPackages = with pkgs; [
    git
    vim
    curl
    dig
    neofetch
    htop
    iftop
    tcpdump
    inetutils
    bottom
    pstreea
    tree
    pwgen
    screen
    ncdu
    parted
    file
    unzip
    lshw
  ];
}
