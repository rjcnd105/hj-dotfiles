{
  config,
  pkgs,
  ...
}:
{
  users.groups.github-runner-homelab = { };

  users.users.github-runner-homelab = {
    isSystemUser = true;
    group = "github-runner-homelab";
  };

  services.github-runners.homelab-deploy = {
    enable = true;
    url = "https://github.com/rjcnd105/hj-dotfiles";
    name = "homelab-deploy";
    tokenFile = config.sops.secrets.GITHUB_RUNNER_HJ_DOTFILES_TOKEN.path;
    extraLabels = [ "homelab" ];
    replace = true;

    user = "github-runner-homelab";
    group = "github-runner-homelab";

    extraPackages = with pkgs; [
      bash
      coreutils
      curl
      jq
      sudo
      systemd
    ];

    # Deploy crosses into host mutation only through narrow sudo rules.
    serviceOverrides = {
      NoNewPrivileges = false;
      PrivateUsers = false;
    };
  };

  systemd.services.github-runner-homelab-deploy = {
    requires = [ "sops-install-secrets.service" ];
    after = [ "sops-install-secrets.service" ];
  };
}
