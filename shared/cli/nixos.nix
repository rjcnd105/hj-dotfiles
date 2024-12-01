{pkgs, ...}: {
  home.shellAliases  = {
    update = "sudo nixos-rebuild switch";
  };
  home.packages = with pkgs; [
    nixd
    nixfmt-rfc-style
  ];
}
