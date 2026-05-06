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
    HINDSIGHT_DB_PASSWORD.mode = "0400";
    OPENROUTER_API_KEY.mode = "0400";
    GROQ_API_KEY.mode = "0400";
    HINDSIGHT_API_TENANT_API_KEY.mode = "0400";
    GITHUB_RUNNER_HJ_DOTFILES_TOKEN.mode = "0400";
  };

  # oci-container environmentFiles에 주입할 dotenv 렌더 파일.
  # 경로는 config.sops.templates."services.env".path — Unit 3에서 참조.
  # oci-container environmentFiles에 주입할 dotenv 렌더 파일.
  # 전 컨테이너 공유 — 각 컨테이너는 필요 변수만 사용, 나머지 무시.
  sops.templates."services.env" = {
    content = ''
      # DB (hindsight-db + hindsight 공용)
      POSTGRES_PASSWORD=${config.sops.placeholder.HINDSIGHT_DB_PASSWORD}
      HINDSIGHT_API_DATABASE_URL=postgresql://hindsight:${config.sops.placeholder.HINDSIGHT_DB_PASSWORD}@127.0.0.1:5432/hindsight
      # LLM API keys (hindsight)
      HINDSIGHT_API_OPENROUTER_API_KEY=${config.sops.placeholder.OPENROUTER_API_KEY}
      HINDSIGHT_API_LLM_API_KEY=${config.sops.placeholder.OPENROUTER_API_KEY}
      HINDSIGHT_API_RETAIN_API_KEY=${config.sops.placeholder.OPENROUTER_API_KEY}
      HINDSIGHT_API_CONSOLIDATION_API_KEY=${config.sops.placeholder.OPENROUTER_API_KEY}
      HINDSIGHT_API_REFLECT_LLM_API_KEY=${config.sops.placeholder.GROQ_API_KEY}
      # Auth (hindsight)
      HINDSIGHT_API_TENANT_API_KEY=${config.sops.placeholder.HINDSIGHT_API_TENANT_API_KEY}
    '';
    mode = "0400";
    owner = "root";
  };
}
