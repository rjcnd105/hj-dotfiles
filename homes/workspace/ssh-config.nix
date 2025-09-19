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

  home.activation = {
    setupSSH = lib.hm.dag.entryBefore [ "writeBoundary" ] ''
      if [ ! -d "$HOME/.ssh" ]; then
        # SSH 디렉토리가 없는 경우 새로 생성
        run mkdir -p "$HOME/.ssh"
        run chmod 700 "$HOME/.ssh"

        # 키가 없는 경우 새로 생성
        if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
          run ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N "" -C "$USER@$(hostname)"
          run chmod 600 "$HOME/.ssh/id_ed25519"
          run chmod 644 "$HOME/.ssh/id_ed25519.pub"
          echo "Created new SSH key"
        fi
      fi
    '';
  };

  # macOS specific: ssh-add to keychain
  home.activation.addSSHKeyToAgent = lib.mkIf pkgs.stdenv.isDarwin (
    lib.hm.dag.entryAfter [ "setupSSH" ] ''
      if [ -f "$HOME/.ssh/id_ed25519" ]; then
        run ssh-add --apple-use-keychain "$HOME/.ssh/id_ed25519" || true
      fi
    ''
  );
}
