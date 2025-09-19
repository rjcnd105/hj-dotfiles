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
    startAgent = true;

    extraConfig = ''
      # AddKeysToAgent yes # 이 옵션은 matchBlocks 로 이동했습니다.
      UseKeychain yes
    '';

    matchBlocks = {
      "*" = {
        addKeysToAgent = "yes";
        forwardAgent = false;
        compression = false;
        serverAliveInterval = 0;
        serverAliveCountMax = 3;
        hashKnownHosts = false;
        userKnownHostsFile = "~/.ssh/known_hosts";
        controlMaster = "no";
        controlPath = "~/.ssh/master-%r@%n:%p";
        controlPersist = "no";
      };
      "github.com" = {
        identityFile = "~/.ssh/id_ed25519";
        identitiesOnly = lib.mkDefault true;
      };
    };
  };

  # macOS specific: ssh-add to keychain
  home.activation.addSSHKeyToAgent = lib.mkIf pkgs.stdenv.isDarwin (
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      if [ -f "$HOME/.ssh/id_ed25519" ]; then
        run ssh-add --apple-use-keychain "$HOME/.ssh/id_ed25519" || true
      fi
    ''
  );
}
