{
  config,
  pkgs,
  ...
}:
let
  telegramBotTokenCredential = "telegram-bot-token";
  telegramChatIdCredential = "telegram-chat-id";

  thermalAlert = pkgs.callPackage ./thermal-alert-package.nix { };
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
      LoadCredential = [
        "${telegramBotTokenCredential}:${config.sops.secrets.TELEGRAM_BOT_TOKEN.path}"
        "${telegramChatIdCredential}:${config.sops.secrets.TELEGRAM_CHAT_ID.path}"
      ];
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
      OnBootSec = "2min";
      OnUnitActiveSec = "1min";
      AccuracySec = "15s";
      Unit = "homelab-thermal-alert.service";
    };
  };
}
