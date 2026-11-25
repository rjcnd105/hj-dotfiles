{ ... }:
{
  boot.loader.grub.enable = false;
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
  };
  system.stateVersion = "26.05";
  networking.hostName = "fixture";

  virtualisation.podman.enable = true;
  homelab.cloudflared.enable = false;

  sops.validateSopsFiles = false;
  sops.defaultSopsFile = ./sops-dummy.yaml;
  sops.age.keyFile = "/var/lib/sops-nix/key.txt";
}
