{
  pkgs,
  customConfig,
  config,
  inputs,
  ...
}:
{
  nix =
    let
      users = [
        "root"
        customConfig.userName
      ];
    in
    {

      settings = {
        experimental-features = "nix-command flakes";
        http-connections = 50;
        warn-dirty = false;
        log-lines = 50;

        # Large builds apparently fail due to an issue with darwin:
        # https://github.com/NixOS/nix/issues/4119
        sandbox = false;

        # This appears to break on darwin
        # https://github.com/NixOS/nix/issues/7273
        auto-optimise-store = false;

        allow-import-from-derivation = true;

        trusted-users = users;
        allowed-users = users;

      };
      optimise.automatic = true;

    };
}
