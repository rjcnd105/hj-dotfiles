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

  # Nix path (path + string = path) — store로 복사되어 빌드 샌드박스에서 접근 가능
  host_secrets_path = ../../secrets + "/${myOptions.hostName}/secrets.yaml";
  last30days_secrets_path = ../../secrets + "/${myOptions.hostName}/last30days.enc.yaml";
  rendered_env_dir = "${config.home.homeDirectory}/.config/sops-nix/secrets/rendered";

  # Single source of truth for env-var names and backing sops secret keys.
  # Adding a key here automatically creates both the sops secret entry and the
  # per-secret rendered env file under ${rendered_env_dir}/env/.
  env_bindings = {
    GITHUB_MASTER_TOKEN = "github_master_token";
    GITHUB_TOKEN = "GITHUB_TOKEN";
    ANTHROPIC_KEY = "anthropic_key";
    ANTHROPIC_API_KEY = "anthropic_key";
    GOOGLE_SEARCH = "google_search";
    OPENAI_GPT_KEY = "openai_gpt_key";
    OPENAI_API_KEY = "openai_gpt_key";
    OPENROUTER_API_KEY = "OPENROUTER_API_KEY";
    BRAVE_API_KEY = "BRAVE_API_KEY";
    CURSOR_BACKGROUND = "cursor_background";
    EXA_API_KEY = "EXA_API_KEY";
    CONTEXT7_API_KEY = "CONTEXT7_API_KEY";
    GEMINI_API_KEY_FREE = "GEMINI_API_KEY_FREE";
    GEMINI_API_KEY = "GEMINI_API_KEY_FREE";
    TELEGRAM_BOT_HJSAGENTBOT = "TELEGRAM_BOT_hjsAgentBot";
    FIGMA_READ_API_KEY = "FIGMA_READ_API_KEY";
    GROQ_API_KEY = "GROQ_API_KEY";
    SCRAPECREATORS_API_KEY = "SCRAPECREATORS_API_KEY";
    AUTH_TOKEN = "AUTH_TOKEN";
    CT0 = "CT0";
    BSKY_HANDLE = "BSKY_HANDLE";
    BSKY_APP_PASSWORD = "BSKY_APP_PASSWORD";
  };

  workspace_env_vars = [
    "GITHUB_MASTER_TOKEN"
    "ANTHROPIC_KEY"
    "GOOGLE_SEARCH"
    "OPENAI_GPT_KEY"
    "OPENROUTER_API_KEY"
    "BRAVE_API_KEY"
    "CURSOR_BACKGROUND"
    "EXA_API_KEY"
    "CONTEXT7_API_KEY"
    "GEMINI_API_KEY_FREE"
    "TELEGRAM_BOT_HJSAGENTBOT"
    "FIGMA_READ_API_KEY"
  ];

  llm_env_vars = [
    "OPENAI_API_KEY"
    "ANTHROPIC_API_KEY"
    "OPENROUTER_API_KEY"
    "EXA_API_KEY"
    "GEMINI_API_KEY"
    "GROQ_API_KEY"
  ];

  last30days_env_vars = [
    "SCRAPECREATORS_API_KEY"
    "OPENAI_API_KEY"
    "BRAVE_API_KEY"
    "OPENROUTER_API_KEY"
    "AUTH_TOKEN"
    "CT0"
    "BSKY_HANDLE"
    "BSKY_APP_PASSWORD"
  ];

  last30days_secret_names = [
    "BSKY_HANDLE"
    "BSKY_APP_PASSWORD"
    "SCRAPECREATORS_API_KEY"
    "AUTH_TOKEN"
    "CT0"
  ];

  mkEnvLine =
    envVar:
    let
      secret = builtins.getAttr envVar env_bindings;
    in
    "${envVar}=${builtins.getAttr secret config.sops.placeholder}";

  mkEnvContent = envVars: ''
    ${builtins.concatStringsSep "\n" (map mkEnvLine envVars)}
  '';

  env_var_names = builtins.attrNames env_bindings;
  secret_names = builtins.attrNames (
    builtins.listToAttrs (
      map (envVar: {
        name = builtins.getAttr envVar env_bindings;
        value = true;
      }) env_var_names
    )
  );

  mkSecretConfig = secret: {
    name = secret;
    value = {
      mode = "600";
    }
    // (
      if builtins.elem secret last30days_secret_names then
        { sopsFile = last30days_secrets_path; }
      else
        { }
    );
  };

  sops_secret_configs = builtins.listToAttrs (map mkSecretConfig secret_names);

  mkSingleSecretEnvTemplate =
    envVar:
    let
      secret = builtins.getAttr envVar env_bindings;
    in
    {
      name = "env/${envVar}.env";
      value = {
        path = "${rendered_env_dir}/env/${envVar}.env";
        content = ''
          ${envVar}=${builtins.getAttr secret config.sops.placeholder}
        '';
      };
    };

  single_secret_env_templates = builtins.listToAttrs (map mkSingleSecretEnvTemplate env_var_names);
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
    WORKSPACE_CONTEXT7_ENV = config.sops.templates."env/CONTEXT7_API_KEY.env".path;
    WORKSPACE_SINGLE_SECRET_ENV_DIR = "${rendered_env_dir}/env";
  };

  sops = {
    age = {
      keyFile = age_key_file;
      generateKey = true;
      sshKeyPaths = [ ssh_key_file ];
    };
    defaultSopsFile = host_secrets_path;

    secrets = sops_secret_configs;

    templates = {
      "workspace-secrets.env".content = mkEnvContent workspace_env_vars;

      "llm.env".content = mkEnvContent llm_env_vars;

      "context7.env".content = mkEnvContent [ "CONTEXT7_API_KEY" ];

      "last30days.env" = {
        path = "${config.home.homeDirectory}/.config/last30days/.env";
        mode = "600";
        content = mkEnvContent last30days_env_vars;
      };
    }
    // single_secret_env_templates;
  };
}
