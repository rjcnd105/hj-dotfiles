{
  config,
  inputs,
  myOptions,
  ...
}:
let
  homelab_secrets = ../../secrets/homelab/services.yaml;
in
{
  imports = [ inputs.sops-nix.nixosModules.sops ];

  # 복호화 키: hj user의 age private key(home-manager 관리).
  # / 와 /home이 동일 btrfs 파티션(subvol @, @home)이라 마운트 타이밍 문제 없음.
  # sops-nix.service는 root 실행이라 0600 hj 파일도 uid=0으로 읽힌다.
  sops.age.keyFile = "/home/${myOptions.userName}/.config/sops/age/keys.txt";

  sops.defaultSopsFile = homelab_secrets;
  # Install /run/secrets via a boot-time systemd unit so runtime services can
  # order themselves after decrypted templates and credentials exist.
  sops.useSystemdActivation = true;

  # 개별 secret 선언 — sops.templates에서 ${placeholder.<key>}로 합성
  sops.secrets = {
    GITHUB_RUNNER_HJ_DOTFILES_TOKEN = {
      mode = "0400";
      owner = "github-runner-homelab";
      group = "github-runner-homelab";
    };
    # private flake input(github:rjcnd105/my-app) fetch 전용 fine-grained PAT.
    NIX_GITHUB_TOKEN.mode = "0400";
  };

  # comin/nixos-rebuild이 private flake input을 fetch할 때 쓰는 토큰.
  # store에는 렌더 경로만 남고 값은 /run/secrets 안에만 있다.
  # `!include`는 optional이라 복호화 전(부팅 초기, 빌드 샌드박스)에도 nix가 깨지지 않는다.
  sops.templates."nix-access-tokens.conf" = {
    content = ''
      access-tokens = github.com=${config.sops.placeholder.NIX_GITHUB_TOKEN}
    '';
    mode = "0400";
    owner = "root";
  };

  nix.extraOptions = ''
    !include ${config.sops.templates."nix-access-tokens.conf".path}
  '';

  # homelab-appctl이 private 릴리스 자산을 받을 때 쓰는 같은 토큰.
  # deploy는 root 작업이라 0400 root 파일을 그대로 읽는다.
  homelab.githubTokenFile = config.sops.secrets.NIX_GITHUB_TOKEN.path;
}
