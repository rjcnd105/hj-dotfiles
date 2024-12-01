{
  options,
  config,
  pkgs,
  lib,
  namespace,
  ...
}:
with lib;
with lib.${namespace};
let
  cfg = config.${namespace}.nix;
in
{
  options.${namespace}.nix = with types; {
    enable = mkBoolOpt true "Whether or not to manage nix configuration.";
    package = mkOpt package pkgs.lix "Which nix package to use.";
  };

  config = mkIf cfg.enable {
    environment.systemPackages = with pkgs; [
      deploy-rs
      nixfmt-rfc-style
      nix-prefetch-git
    ];

    nix =
      let
        users = [
          "root"
          config.${namespace}.user.name
        ];
      in
      {
        package = cfg.package;

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

          # NOTE: This configuration is generated by nix-installer so I'm adding it here in
          # case it becomes important.
          extra-nix-path = "nixpkgs=flake:nixpkgs";
          build-users-group = "nixbld";
        };
        #// (lib.optionalAttrs config.${namespace}.tools.direnv.enable {
        #  keep-outputs = true;
        #  keep-derivations = true;
        #});

        gc = {
          automatic = true;
          interval = {
            Day = 7;
          };
          options = "--delete-older-than 30d";
          user = config.${namespace}.user.name;
        };

        # flake-utils-plus
        generateRegistryFromInputs = true;
        generateNixPathFromInputs = true;
        linkInputs = true;
      };
  };
}
