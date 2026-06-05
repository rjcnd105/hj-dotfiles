{
  config,
  lib,
  pkgs,
  ...
}:
{
  programs.ssh = {
    enable = true;
    enableDefaultConfig = false;

    includes = [ "~/.ssh/config.d/*" ];

    extraConfig = lib.optionalString pkgs.stdenv.isDarwin ''
      UseKeychain yes
    '';

    settings = {
      "*" = {
        AddKeysToAgent = "yes";
        ForwardAgent = false;
        Compression = false;
        ServerAliveInterval = 0;
        ServerAliveCountMax = 3;
        HashKnownHosts = false;
        UserKnownHostsFile = "~/.ssh/known_hosts";
        ControlMaster = "no";
        ControlPath = "~/.ssh/master-%r@%n:%p";
        ControlPersist = "no";
      };
      "github.com" = {
        IdentityFile = [ "~/.ssh/id_ed25519" ];
        IdentitiesOnly = lib.mkDefault true;
      };
    };
  };

  # macOS specific: ssh-add to keychain
  home.activation.addSSHKeyToAgent = lib.mkIf pkgs.stdenv.isDarwin (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -f "$HOME/.ssh/id_ed25519" ]; then
        run /usr/bin/ssh-add --apple-use-keychain "$HOME/.ssh/id_ed25519" || true
      fi
    ''
  );
}
