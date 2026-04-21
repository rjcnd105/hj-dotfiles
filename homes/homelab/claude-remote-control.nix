{ pkgs, ... }:
{
  # Claude Code Remote Control — claude.ai 모바일/웹 앱에서 접속할 수 있는 상주 세션
  # 아웃바운드 HTTPS only, 방화벽 개방 불필요
  #
  # ExecStart wrapper: `echo y | claude` — 첫 실행 시 표시되는
  # "Enable Remote Control? (y/n)" 일회성 동의 prompt 자동 통과 (systemd stdin 부재 회피)
  systemd.user.services.claude-remote-control = {
    Unit = {
      Description = "Claude Code Remote Control daemon";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "simple";
      WorkingDirectory = "/etc/nixos";
      ExecStart = "${pkgs.bash}/bin/bash -c 'echo y | exec ${pkgs.claude-code}/bin/claude remote-control --capacity 4'";
      Restart = "always";
      RestartSec = 30;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
