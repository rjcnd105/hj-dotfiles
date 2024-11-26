{ config, lib, pkgs, ... }:
{
  programs.ssh = {
    enable = true;

    extraConfig = ''
      AddKeysToAgent yes
      UseKeychain yes
    '';

    matchBlocks = {
      "github.com" = {
        identityFile = "~/.ssh/id_ed25519";
        identitiesOnly = lib.mkDefault true;
      };
    };
  };

  home.activation = {
    setupSSH = lib.hm.dag.entryAfter ["writeBoundary"] ''
      if [ ! -d "$HOME/.ssh" ]; then
        # SSH 디렉토리가 없는 경우 새로 생성
        $DRY_RUN_CMD mkdir -p "$HOME/.ssh"
        $DRY_RUN_CMD chmod 700 "$HOME/.ssh"

        # 키가 없는 경우 새로 생성
        if [ ! -f "$HOME/.ssh/id_ed25519" ]; then
          $DRY_RUN_CMD ssh-keygen -t ed25519 -f "$HOME/.ssh/id_ed25519" -N "" -C "$USER@$(hostname)"
          $DRY_RUN_CMD chmod 600 "$HOME/.ssh/id_ed25519"
          $DRY_RUN_CMD chmod 644 "$HOME/.ssh/id_ed25519.pub"
          echo "Created new SSH key"
        fi
      else
        # 기존 SSH 디렉토리가 있는 경우
        echo "Existing SSH directory found"

        # 백업 디렉토리 생성
        backup_dir="$HOME/.ssh_backup_$(date +%Y%m%d_%H%M%S)"
        $DRY_RUN_CMD mkdir -p "$backup_dir"

        # 기존 파일 백업
        $DRY_RUN_CMD cp -r "$HOME/.ssh/"* "$backup_dir/"
        echo "Backed up existing SSH files to $backup_dir"

        # 권한 설정
        $DRY_RUN_CMD chmod 700 "$HOME/.ssh"
        if [ -f "$HOME/.ssh/id_ed25519" ]; then
          $DRY_RUN_CMD chmod 600 "$HOME/.ssh/id_ed25519"
        fi
        if [ -f "$HOME/.ssh/id_ed25519.pub" ]; then
          $DRY_RUN_CMD chmod 644 "$HOME/.ssh/id_ed25519.pub"
        fi
      fi
    '';
  };

  # macOS specific: ssh-add to keychain
  home.activation.addSSHKeyToAgent = lib.mkIf pkgs.stdenv.isDarwin (
    lib.hm.dag.entryAfter ["setupSSH"] ''
      if [ -f "$HOME/.ssh/id_ed25519" ]; then
        $DRY_RUN_CMD ssh-add --apple-use-keychain "$HOME/.ssh/id_ed25519" || true
      fi
    ''
  );
}
