{ pkgs, ... }:
let
  dockerCompat = pkgs.writeShellScriptBin "docker" ''
    exec ${pkgs.podman}/bin/podman "$@"
  '';
  dockerComposeCompat = pkgs.writeShellScriptBin "docker-compose" ''
    exec ${pkgs.podman-compose}/bin/podman-compose "$@"
  '';
in
{
  imports = [
    ../file.nix
    ./home-config.nix
    ./ssh-config.nix
    ./sops.nix
    ../../sharedHome/cli
    ../../sharedHome/development
    # ../../sharedHome/app
  ];

  home.packages = with pkgs; [
    podman
    podman-compose
    dockerCompat
    dockerComposeCompat
  ];
}
