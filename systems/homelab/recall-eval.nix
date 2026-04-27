{
  config,
  pkgs,
  ...
}:
let
  recallEvalPkg = pkgs.buildGoModule {
    pname = "recall-eval";
    version = "0.1.0";
    src = ./recall-eval;
    vendorHash = "sha256-g+yaVIx4jxpAQ/+WrGKxhVeliYx7nLQe/zsGpxV4Fn4=";
  };

  waitForHindsightHealth = pkgs.writeShellScript "recall-eval-wait-for-hindsight-health" ''
    for _ in $(${pkgs.coreutils}/bin/seq 1 30); do
      if ${pkgs.curl}/bin/curl -fsS --max-time 2 http://127.0.0.1:8888/health >/dev/null; then
        exit 0
      fi
      ${pkgs.coreutils}/bin/sleep 2
    done

    echo "warning: Hindsight /health not ready after 60s; running recall eval anyway" >&2
    exit 0
  '';

  # systemd exposes LoadCredential= files through CREDENTIALS_DIRECTORY.
  # Hard-coded /run/credentials/%N is brittle: on this host %N expands without
  # the .service suffix and missed the actual credential file.
  credFixturesPath = "\${CREDENTIALS_DIRECTORY}/fixtures.yaml";

  commonServiceConfig = {
    Type = "oneshot";
    DynamicUser = true;
    StateDirectory = "recall-eval";
    StateDirectoryMode = "0700";
    EnvironmentFile = config.sops.templates."recall-eval.env".path;
    LoadCredential = [
      "fixtures.yaml:${config.sops.secrets."recall-eval-fixtures".path}"
    ];
    ProtectSystem = "strict";
    ProtectHome = true;
    PrivateTmp = true;
    NoNewPrivileges = true;
  };
in
{
  sops.secrets.TELEGRAM_BOT_TOKEN.mode = "0400";
  sops.secrets.TELEGRAM_CHAT_ID.mode = "0400";

  sops.secrets."recall-eval-fixtures" = {
    sopsFile = ../../secrets/homelab/recall-eval-fixtures.yaml;
    format = "binary";
    mode = "0400";
  };

  sops.templates."recall-eval.env" = {
    content = ''
      HINDSIGHT_API_TENANT_API_KEY=${config.sops.placeholder.HINDSIGHT_API_TENANT_API_KEY}
      TELEGRAM_BOT_TOKEN=${config.sops.placeholder.TELEGRAM_BOT_TOKEN}
      TELEGRAM_CHAT_ID=${config.sops.placeholder.TELEGRAM_CHAT_ID}
      HINDSIGHT_IMAGE_TAG=0.5.2-slim
    '';
    mode = "0400";
    owner = "root";
  };

  systemd.services.recall-eval-gate = {
    description = "recall eval — manual strict gate";
    requires = [ "sops-install-secrets.service" ];
    after = [
      "sops-install-secrets.service"
      "hindsight.service"
      "embed-prefix-proxy.service"
      "llama-swap.service"
    ];
    serviceConfig = commonServiceConfig // {
      ExecStart = "${recallEvalPkg}/bin/recall-eval --mode gate --fixtures ${credFixturesPath} --state-dir /var/lib/recall-eval";
    };
    restartTriggers = [
      recallEvalPkg
      config.sops.templates."recall-eval.env".path
    ];
  };

  systemd.services.recall-eval-on-switch = {
    description = "recall eval — post-switch alert-only run";
    requires = [ "sops-install-secrets.service" ];
    after = [
      "sops-install-secrets.service"
      "hindsight.service"
      "embed-prefix-proxy.service"
      "llama-swap.service"
    ];
    unitConfig = {
      StartLimitIntervalSec = 600;
      StartLimitBurst = 2;
    };
    serviceConfig = commonServiceConfig // {
      ExecStartPre = waitForHindsightHealth;
      ExecStart = "${recallEvalPkg}/bin/recall-eval --mode on-switch --fixtures ${credFixturesPath} --state-dir /var/lib/recall-eval";
    };
    restartTriggers = [
      recallEvalPkg
      config.sops.templates."recall-eval.env".path
    ];
  };

  systemd.services.recall-eval-ack = {
    description = "recall eval — acknowledge all current alerts";
    requires = [ "sops-install-secrets.service" ];
    after = [ "sops-install-secrets.service" ];
    serviceConfig = commonServiceConfig // {
      ExecStart = "${recallEvalPkg}/bin/recall-eval --mode ack-all --state-dir /var/lib/recall-eval";
    };
  };

  # Fires after every nixos-rebuild switch (including comin auto-switch).
  # Intentionally alert-only: eval failure must not fail the switch itself.
  system.activationScripts.recallEvalOnSwitch = {
    text = ''
      ${pkgs.systemd}/bin/systemctl start --no-block recall-eval-on-switch.service || true
    '';
    deps = [
      "specialfs"
      "hindsightQuadletRefresh"
    ];
  };
}
