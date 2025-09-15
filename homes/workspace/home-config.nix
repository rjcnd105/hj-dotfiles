{
  config,
  inputs,
  pkgs,
  lib,
  myOptions,
  ...
}:
let

  sops_dir = "${config.home.homeDirectory}/.config/sops";
  sops_age_dir = sops_dir + "/age";
  age_key_file = sops_age_dir + "/keys.txt";

  user_secrets_path = "${myOptions.absoluteProjectPath}/secrets/workspace/secrets.yaml";
in
# aqua = import (myOptions.paths.pkgs + "/aqua.nix") {
#   inherit pkgs;
# };
{
  home.username = myOptions.userName;

  # services = {
  #   gpg-agent = {
  #     enable = true;
  #     defaultCacheTtl = 1800;
  #     enableSshSupport = true;
  #   };
  # };

  home.shellAliases = {
    grep = "rg";
    find = "fd";
    sd = "sed";
    ping = "gping"; # 그래픽 ping
    pskill = "ps -f | fzf | awk '{print $2}' | xargs kill";
  };

  home.sessionVariables = {
    ZELLIJ_CONFIG_DIR = "$HOME/.config/zellij";
    HOME_VERSION = inputs.nixpkgs.lib.trivial.release;
    AQUA_GLOBAL_CONFIG = config.xdg.configHome + "/aqua/aqua.toml";
    PROJECT_PATH = "${myOptions.absoluteProjectPath}";
    VISUAL = pkgs.zed + "/bin/zed";
    EDITOR = pkgs.helix + "/bin/hx";
    USER_PROFILE = config.home.profileDirectory;
    XDG_BIN_HOME = "$HOME/.local/bin";
    HM_CURRENT = "/run/current-system/sw";

    ZED_ALLOW_ROOT = "true";
  };

  home.sessionPath = [
    "$XDG_BIN_HOME"
    "$HOME/.local/share/mise/installs"
  ];

  home.stateVersion = inputs.nixpkgs.lib.trivial.release;

  home.packages =
    with pkgs;
    [
      zsh
      helix
      ripgrep # grep 대체 (rg)
      sd # sed 대체 (더 직관적)
      hyperfine # 벤치마크 도구
      termshark # Wireshark의 TUI 버전
      bandwhich # 실시간 네트워크 사용량을 프로세스별로 표시
      mtr-gui # traceroute 대체, 더 상호작용적
      jq # json 파싱
      tlrc # 문서 보기
      coreutils # 기본 유틸리티
      file # 파일 타입 확인
      fd # find 대체
      restic # 백업 도구
      nmap # 네트워크 스캔
      pwgen # 패스워드 생성
      fastfetch # 빠른 fetch
      curl # 다운로드
      procs
      gping # ping 대체, 그래프 표시 기능
      dua # 디스크 사용량
      p7zip
      fontconfig
      zstd

    ]
    ++ [
      pkgs.nerd-fonts.d2coding
      pkgs.nerd-fonts.jetbrains-mono
      # 필요한 다른 폰트들...
      #
      # aqua
    ];

  home.shellAliases = {
    lzg = "lazygit";
  };

  # @see https://github.com/nix-community/home-manager/blob/master/modules/files.nix
  home.activation = {

    # sopsSetup = lib.hm.dag.entryAfter [ "onFilesChange" ] ''
    #   SOPS_AGE_DIR="${sops_age_dir}"
    #   AGE_KEY_FILE="${age_key_file}"

    #   if [[ ! -d "$SOPS_AGE_DIR" ]]; then
    #     mkdir -p "$SOPS_AGE_DIR"
    #     echo "Created sops age directory: $SOPS_AGE_DIR"
    #   fi

    #   # age 키가 없는 경우에만 생성
    #   if [[ ! -f "$AGE_KEY_FILE" ]]; then
    #     echo "Generating new age key for sops..."
    #     ${pkgs.age}/bin/age-keygen -o "$AGE_KEY_FILE"
    #     chmod 600 "$AGE_KEY_FILE"
    #     echo "Age key generated at: $AGE_KEY_FILE"

    #     # Public key 표시
    #     if [[ -f "$AGE_KEY_FILE" && -z "$DRY_RUN_CMD" ]]; then
    #       echo "=== Your age public key ==="
    #       ${pkgs.age}/bin/age-keygen -y "$AGE_KEY_FILE"
    #       echo "=== Add this key to your .sops.yaml file ==="
    #     fi
    #   else
    #     echo "Age key already exists at: $AGE_KEY_FILE"
    #   fi
    # '';

    miseInstall = lib.hm.dag.entryAfter [ "onFilesChange" ] ''
      run ${pkgs.mise}/bin/mise install
    '';
  };


  fonts.fontconfig.enable = true;
}
