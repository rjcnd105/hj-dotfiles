{
  config,
  pkgs,
  ...
}:
let
  telegramBotTokenCredential = "telegram-bot-token";
  telegramChatIdCredential = "telegram-chat-id";

  thermalAlert = pkgs.writeShellApplication {
    name = "homelab-thermal-alert";
    runtimeInputs = [
      pkgs.coreutils
      pkgs.curl
      pkgs.gawk
      pkgs.procps
    ];
    text = builtins.readFile ./thermal-alert.sh;
  };
in
{
  sops.secrets.TELEGRAM_BOT_TOKEN.mode = "0400";
  sops.secrets.TELEGRAM_CHAT_ID.mode = "0400";

  systemd.services.homelab-thermal-alert = {
    description = "Send Telegram alert when homelab CPU temperature is high";
    requires = [ "sops-install-secrets.service" ];
    after = [ "sops-install-secrets.service" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${thermalAlert}/bin/homelab-thermal-alert";
      DynamicUser = true;
      # Keep Telegram secrets out of the Nix store and the service environment.
      # systemd exposes them as files under CREDENTIALS_DIRECTORY for this run.
      LoadCredential = [
        "${telegramBotTokenCredential}:${config.sops.secrets.TELEGRAM_BOT_TOKEN.path}"
        "${telegramChatIdCredential}:${config.sops.secrets.TELEGRAM_CHAT_ID.path}"
      ];
      # RuntimeDirectory holds per-run Telegram request files on /run; StateDirectory
      # keeps only the cooldown timestamp across timer runs.
      RuntimeDirectory = "homelab-thermal-alert";
      RuntimeDirectoryMode = "0700";
      StateDirectory = "homelab-thermal-alert";
      StateDirectoryMode = "0700";
      ProtectSystem = "strict";
      ProtectHome = true;
      PrivateTmp = true;
      NoNewPrivileges = true;
    };
  };

  systemd.timers.homelab-thermal-alert = {
    description = "Poll homelab CPU temperature for Telegram alerts";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      # Leave boot a little time to settle before checking sensors/network.
      OnBootSec = "2min";
      OnUnitActiveSec = "1min";
      AccuracySec = "15s";
      Unit = "homelab-thermal-alert.service";
    };
  };
}
