{ pkgs, ... }:
{
  # Claude Code Remote Control — claude.ai 모바일/웹 앱에서 접속할 수 있는 상주 세션
  # 아웃바운드 HTTPS only, 방화벽 개방 불필요
  systemd.user.services.claude-remote-control = {
    Unit = {
      Description = "Claude Code Remote Control daemon";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "simple";
      WorkingDirectory = "/etc/nixos";
      ExecStart = "${pkgs.claude-code}/bin/claude remote-control --capacity 4";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
