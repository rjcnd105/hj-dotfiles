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

  user_secrets_path = "${myOptions.absoluteProjectPath}/secrets/workspace/secrets.yaml";
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
      AGE_KEY_FILE = age_key_file;
  };

  sops = {
    age = {
      keyFile = age_key_file;
      generateKey = true;
      sshKeyPaths = [ ssh_key_file ];
    };
    defaultSopsFile = user_secrets_path;

    # secrets 정의
    secrets = {
      # 개인용 github token
      "github-token" = {
        mode = "600";
        # 기본 경로: ~/.config/sops/secrets/github-token
      };
    };
  };
}
