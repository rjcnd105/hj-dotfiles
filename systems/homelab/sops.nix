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

  sops.age.keyFile = "/home/${myOptions.userName}/.config/sops/age/keys.txt";

  sops.defaultSopsFile = homelab_secrets;
  sops.useSystemdActivation = true;

  sops.secrets = {
    GITHUB_RUNNER_HJ_DOTFILES_TOKEN = {
      mode = "0400";
      owner = "github-runner-homelab";
      group = "github-runner-homelab";
    };
    NIX_GITHUB_TOKEN.mode = "0400";
  };

  sops.templates."nix-access-tokens.conf" = {
    content = ''
      access-tokens = github.com=${config.sops.placeholder.NIX_GITHUB_TOKEN}
    '';
    mode = "0400";
    owner = "root";
  };

  # `!include`는 optional이라 복호화 전(부팅 초기, 빌드 샌드박스)에도 nix가 깨지지 않는다.
  nix.extraOptions = ''
    !include ${config.sops.templates."nix-access-tokens.conf".path}
  '';

  homelab.githubTokenFile = config.sops.secrets.NIX_GITHUB_TOKEN.path;
}
