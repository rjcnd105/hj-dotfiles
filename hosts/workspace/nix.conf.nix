{ host, config, ... }:
{
  nix = {
    settings = {
      trusted-users = [
        "root"
        host.user
      ];
      keep-derivations = true;
      keep-outputs = true;
      experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
    configureBuildUsers = true;
    optimise.automatic = true;

    # garbage collection
    gc = {
      automatic = true;
      options = "--delete-older-than 45d";
    };
  };
}