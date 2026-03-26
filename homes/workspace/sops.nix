{
  config,
  myOptions,
  pkgs,
  ...
}:
let

  sops_dir = "${config.home.homeDirectory}/.config/sops";
  sops_age_dir = sops_dir + "/age";
  age_key_file = sops_age_dir + "/keys.txt";
  ssh_key_file = "${config.home.homeDirectory}/.ssh/id_ed25519";

  host_secrets_path = "${myOptions.absoluteProjectPath}/secrets/${myOptions.hostName}/secrets.yaml";
  last30days_secrets_path = "${myOptions.absoluteProjectPath}/secrets/${myOptions.hostName}/last30days.enc.yaml";
in
{

  ## ssh to age
  # nix-shell -p ssh-to-age --run 'cat ~/.ssh/id_ed25519.pub | ssh-to-age'

  home.packages = [
    # 암호관리
    pkgs.sops
    pkgs.age
  ];

  home.sessionVariables = {
    SOPS_DIR = sops_dir;
    SOPS_AGE_KEY_FILE = age_key_file;
    WORKSPACE_SECRETS_ENV = config.sops.templates."workspace-secrets.env".path;
    WORKSPACE_LLM_ENV = config.sops.templates."llm.env".path;
  };

  sops = {
    age = {
      keyFile = age_key_file;
      generateKey = true;
      sshKeyPaths = [ ssh_key_file ];
    };
    defaultSopsFile = host_secrets_path;

    # secrets 정의
    secrets = {
      # 개인용 github token
      "github_master_token" = {
        mode = "600";
        # 기본 경로: ~/.config/sops/secrets/github-token
      };
      "anthropic_key".mode = "600";
      "google_search".mode = "600";
      "openai_gpt_key".mode = "600";
      "OPENROUTER_API_KEY".mode = "600";
      "BRAVE_API_KEY".mode = "600";
      "cursor_background".mode = "600";
      "EXA_API_KEY".mode = "600";
      "CONTEXT7_API_KEY".mode = "600";
      "GEMINI_API_KEY_FREE".mode = "600";
      "TELEGRAM_BOT_hjsAgentBot".mode = "600";
      "GROQ_API_KEY".mode = "600";


      "BSKY_HANDLE" = {
        mode = "600";
        sopsFile = last30days_secrets_path;
      };
      "BSKY_APP_PASSWORD" = {
        mode = "600";
        sopsFile = last30days_secrets_path;
      };
      "SCRAPECREATORS_API_KEY" = {
        mode = "600";
        sopsFile = last30days_secrets_path;
      };
      "AUTH_TOKEN" = {
        mode = "600";
        sopsFile = last30days_secrets_path;
      };
      "CT0" = {
        mode = "600";
        sopsFile = last30days_secrets_path;
      };


    };

    templates = {
      "workspace-secrets.env".content = ''
        GITHUB_MASTER_TOKEN=${config.sops.placeholder.github_master_token}
        ANTHROPIC_KEY=${config.sops.placeholder.anthropic_key}
        GOOGLE_SEARCH=${config.sops.placeholder.google_search}
        OPENAI_GPT_KEY=${config.sops.placeholder.openai_gpt_key}
        OPENROUTER_API_KEY=${config.sops.placeholder."OPENROUTER_API_KEY"}
        BRAVE_API_KEY=${config.sops.placeholder."BRAVE_API_KEY"}
        CURSOR_BACKGROUND=${config.sops.placeholder.cursor_background}
        EXA_API_KEY=${config.sops.placeholder."EXA_API_KEY"}
        CONTEXT7_API_KEY=${config.sops.placeholder."CONTEXT7_API_KEY"}
        GEMINI_API_KEY_FREE=${config.sops.placeholder."GEMINI_API_KEY_FREE"}
        TELEGRAM_BOT_HJSAGENTBOT=${config.sops.placeholder."TELEGRAM_BOT_hjsAgentBot"}
      '';

      "llm.env".content = ''
        OPENAI_API_KEY=${config.sops.placeholder.openai_gpt_key}
        ANTHROPIC_API_KEY=${config.sops.placeholder.anthropic_key}
        OPENROUTER_API_KEY=${config.sops.placeholder."OPENROUTER_API_KEY"}
        EXA_API_KEY=${config.sops.placeholder."EXA_API_KEY"}
        GEMINI_API_KEY=${config.sops.placeholder."GEMINI_API_KEY_FREE"}
        GROQ_API_KEY=${config.sops.placeholder."GROQ_API_KEY"}
      '';

      "last30days.env" = {
        path = "${config.home.homeDirectory}/.config/last30days/.env";
        mode = "600";
        content = ''
          # Reddit + TikTok + Instagram (one key, all three) - scrapecreators.com
          SCRAPECREATORS_API_KEY=${config.sops.placeholder."SCRAPECREATORS_API_KEY"}
          # optional - legacy Reddit fallback if using `codex login`
          OPENAI_API_KEY=${config.sops.placeholder.openai_gpt_key}
          # recommended for X search - copy once from x.com cookies
          AUTH_TOKEN=${config.sops.placeholder."AUTH_TOKEN"}
          # recommended for X search - copy once from x.com cookies
          CT0=${config.sops.placeholder."CT0"}
          # optional - Bluesky search (create app password below)
          BSKY_HANDLE=${config.sops.placeholder."BSKY_HANDLE"}
          # optional - bsky.app/settings/app-passwords
          BSKY_APP_PASSWORD=${config.sops.placeholder."BSKY_APP_PASSWORD"}
        '';
      };
    };
  };
}
