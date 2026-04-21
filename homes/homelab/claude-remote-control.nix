{ pkgs, ... }:
{
  # Claude Code Remote Control — claude.ai 모바일/웹 앱에서 접속할 수 있는 상주 세션
  # 아웃바운드 HTTPS only, 방화벽 개방 불필요
  #
  # ExecStart wrapper: `echo y | claude` — 첫 실행 시 표시되는
  # "Enable Remote Control? (y/n)" 일회성 동의 prompt 자동 통과 (systemd stdin 부재 회피)
  #
  # X-RestartIfChanged=false — 재배포 시 unit 정의가 바뀌어도 기존 세션 보존.
  # 매 재기동마다 새 environment_id가 발급되어 claude.ai 앱에 stale entry가
  # 누적되는 문제 방지. 새 정의는 서비스가 죽거나 수동 restart 시에만 반영.
  # Restart=always는 유지 — 서비스 crash 시엔 즉시 자동 재기동.
  systemd.user.services.claude-remote-control = {
    Unit = {
      Description = "Claude Code Remote Control daemon";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      X-RestartIfChanged = false;
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
