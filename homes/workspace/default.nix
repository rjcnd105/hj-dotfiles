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

}
