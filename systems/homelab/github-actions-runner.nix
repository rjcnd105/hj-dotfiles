{
  config,
  lib,
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
      systemd
    ];

    # GitHub runner defaults are hardened for unprivileged CI. This runner
    # executes host-owned deploy workflows through a narrow sudo allowlist.
    serviceOverrides = {
      CapabilityBoundingSet = lib.mkForce [ "~" ];
      NoNewPrivileges = false;
      PrivateMounts = false;
      PrivateUsers = false;
      ProtectSystem = false;
      RestrictNamespaces = false;
      RestrictSUIDSGID = false;
      SystemCallFilter = lib.mkForce [ ];
    };
  };

  systemd.services.github-runner-homelab-deploy = {
    requires = [ "sops-install-secrets.service" ];
    after = [ "sops-install-secrets.service" ];
  };
}
