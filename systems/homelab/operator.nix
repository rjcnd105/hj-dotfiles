{ myOptions, ... }:
{
  # Claude 세션(hj SSH)이 비밀번호 없이 호스트를 운영·검증하기 위한 허용목록.
  # systemctl/podman 허용은 사실상 root 등가이므로 이 목록은 보안 경계가 아니라
  # "운영 도구로 쓰는 명령"을 명시하는 경계다. hj SSH 키가 실질 보안 경계.
  security.sudo.extraRules = [
    {
      users = [ myOptions.userName ];
      runAs = "root";
      commands =
        map
          (command: {
            inherit command;
            options = [ "NOPASSWD" ];
          })
          [
            "/run/current-system/sw/bin/systemctl *"
            "/run/current-system/sw/bin/journalctl *"
            "/run/current-system/sw/bin/podman *"
            "/run/current-system/sw/bin/homelab-appctl *"
            "/run/current-system/sw/bin/nix-collect-garbage *"
            "/run/current-system/sw/bin/btrfs *"
            "/run/current-system/sw/bin/restic-homelab *"
          ];
    }
  ];
}
