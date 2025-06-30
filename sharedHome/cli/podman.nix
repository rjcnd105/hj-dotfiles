{ pkgs, lib, config, ... }:
{
  # https://github.com/containers/podman
  home.packages = with pkgs; [
    podman
    podman-compose
    podman-desktop
  ];
  

  # Docker 호환성을 위한 설정
  home.sessionVariables = {
    DOCKER_HOST = "unix://${config.home.homeDirectory}/.local/share/containers/podman/machine/podman.sock";
  };

  launchd.agents."start-podman-machine" = {
    enable = true;
    config = {
      Label = "com.user.start-podman-machine";
      ProgramArguments = [ 
        "${pkgs.podman}/bin/podman"
        "machine"
        "start"
        "podman-machine-default" # 기본 머신 이름, 다를 경우 수정 필요
      ];
      RunAtLoad = true;
      # KeepAlive = false; # 한 번 실행 후 종료
      # StandardOutPath = "/tmp/start-podman-machine.log";
      # StandardErrorPath = "/tmp/start-podman-machine.err";
    };
  };
}
