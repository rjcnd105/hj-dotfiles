{
  config,
  lib,
  myOptions,
  pkgs,
  ...
}:
let
  miseBin = "/opt/homebrew/bin/mise";
  profileBin = "/etc/profiles/per-user/${config.home.username}/bin";

  lspmuxConfig = ''
    instance_timeout = 300
    gc_interval = 10
    listen = ["127.0.0.1", 27631]
    connect = ["127.0.0.1", 27631]
    log_filters = "info"
    pass_environment = [
      "PATH",
      "HOME",
      "USER",
      "USER_HOST",
      "LOGNAME",
      "SHELL",
      "TMPDIR",
      "LANG",
      "LC_*",
      "XDG_*",
      "MISE_BIN",
      "MISE_*",
      "SOPS_AGE_KEY_FILE",
      "ASDF_*",
      "ERL_*",
      "ELIXIR_*",
      "MIX_*",
      "HEX_*",
      "RUSTUP_*",
      "CARGO_*",
      "GOPATH",
      "GOROOT",
      "PROJECT_PATH",
      "NIX_*",
    ]
  '';

  miseGuiBootstrap = ''
    # GUI apps can launch wrappers with a sparse env; mise needs these to load project config.
    export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin''${PATH:+:$PATH}"
    export HOME="''${HOME:-${config.home.homeDirectory}}"
    export USER="''${USER:-${config.home.username}}"
    export USER_HOST="''${USER_HOST:-${myOptions.hostName}}"
    export LOGNAME="''${LOGNAME:-${config.home.username}}"
    export PROJECT_PATH="''${PROJECT_PATH:-${myOptions.absoluteProjectPath}}"
    export SOPS_AGE_KEY_FILE="''${SOPS_AGE_KEY_FILE:-${config.xdg.configHome}/sops/age/keys.txt}"
  '';

  serverDefinitions = [
    {
      name = "nixd";
      wrapperName = "lspmux-nix-nixd";
      provider = "nix";
      serverPath = lib.getExe pkgs.nixd;
      languages = [ "nix" ];
      notes = "Nix-owned server; all clients still enter through lspmux.";
    }
    {
      name = "elixir-ls";
      wrapperName = "lspmux-mise-elixir-ls";
      provider = "mise";
      server = "elixir-ls";
      shell = "/bin/bash";
      versionFromMiseTool = "elixir-ls";
      languages = [
        "elixir"
        "heex"
      ];
      notes = "Primary Elixir LSP.";
    }
    {
      name = "expert";
      wrapperName = "lspmux-mise-expert";
      provider = "mise";
      server = "expert";
      serverArgs = [ "--stdio" ];
      versionFromMiseTool = "expert";
      languages = [
        "elixir"
        "heex"
      ];
      notes = "Secondary Elixir LSP after elixir-ls.";
    }
    {
      name = "rust-analyzer";
      wrapperName = "lspmux-mise-rust-analyzer";
      provider = "mise";
      server = "rust-analyzer";
      languages = [ "rust" ];
    }
    {
      name = "vtsls";
      wrapperName = "lspmux-mise-vtsls";
      provider = "mise";
      server = "vtsls";
      serverArgs = [ "--stdio" ];
      versionFromMiseTool = "npm:@vtsls/language-server";
      languages = [
        "javascript"
        "typescript"
        "tsx"
      ];
    }
    {
      name = "html-language-server";
      wrapperName = "lspmux-mise-html-language-server";
      provider = "mise";
      server = "vscode-html-language-server";
      serverArgs = [ "--stdio" ];
      versionFromMiseTool = "npm:vscode-langservers-extracted";
      languages = [
        "html"
        "heex"
      ];
    }
    {
      name = "css-language-server";
      wrapperName = "lspmux-mise-css-language-server";
      provider = "mise";
      server = "vscode-css-language-server";
      serverArgs = [ "--stdio" ];
      versionFromMiseTool = "npm:vscode-langservers-extracted";
      languages = [
        "css"
        "scss"
        "less"
      ];
    }
    {
      name = "json-language-server";
      wrapperName = "lspmux-mise-json-language-server";
      provider = "mise";
      server = "vscode-json-language-server";
      serverArgs = [ "--stdio" ];
      versionFromMiseTool = "npm:vscode-langservers-extracted";
      languages = [
        "json"
        "jsonc"
      ];
    }
    {
      name = "eslint-language-server";
      wrapperName = "lspmux-mise-eslint-language-server";
      provider = "mise";
      server = "vscode-eslint-language-server";
      serverArgs = [ "--stdio" ];
      versionFromMiseTool = "npm:vscode-langservers-extracted";
      languages = [
        "javascript"
        "typescript"
        "tsx"
      ];
    }
    {
      name = "markdown-language-server";
      wrapperName = "lspmux-mise-markdown-language-server";
      provider = "mise";
      server = "vscode-markdown-language-server";
      serverArgs = [ "--stdio" ];
      versionFromMiseTool = "npm:vscode-langservers-extracted";
      languages = [ "markdown" ];
    }
    {
      name = "tailwindcss-language-server";
      wrapperName = "lspmux-mise-tailwindcss-language-server";
      provider = "mise";
      server = "tailwindcss-language-server";
      serverArgs = [ "--stdio" ];
      versionFromMiseTool = "npm:@tailwindcss/language-server";
      languages = [
        "html"
        "css"
        "javascript"
        "typescript"
        "tsx"
        "elixir"
        "heex"
      ];
    }
    {
      name = "emmet-language-server";
      wrapperName = "lspmux-mise-emmet-language-server";
      provider = "mise";
      server = "emmet-language-server";
      serverArgs = [ "--stdio" ];
      versionFromMiseTool = "npm:@olrtg/emmet-language-server";
      languages = [
        "html"
        "css"
        "elixir"
        "heex"
      ];
    }
    {
      name = "gopls";
      wrapperName = "lspmux-mise-gopls";
      provider = "mise";
      server = "gopls";
      versionFromMiseTool = "go:golang.org/x/tools/gopls";
      languages = [ "go" ];
    }
    {
      name = "yaml-language-server";
      wrapperName = "lspmux-mise-yaml-language-server";
      provider = "mise";
      server = "yaml-language-server";
      serverArgs = [ "--stdio" ];
      versionFromMiseTool = "npm:yaml-language-server";
      languages = [ "yaml" ];
    }
    {
      name = "bash-language-server";
      wrapperName = "lspmux-mise-bash-language-server";
      provider = "mise";
      server = "bash-language-server";
      serverArgs = [ "start" ];
      versionFromMiseTool = "npm:bash-language-server";
      languages = [
        "bash"
        "shell"
      ];
    }
    {
      name = "docker-langserver";
      wrapperName = "lspmux-mise-docker-langserver";
      provider = "mise";
      server = "docker-langserver";
      serverArgs = [ "--stdio" ];
      versionFromMiseTool = "npm:dockerfile-language-server-nodejs";
      languages = [ "dockerfile" ];
    }
    {
      name = "taplo";
      wrapperName = "lspmux-mise-taplo";
      provider = "mise";
      server = "taplo";
      serverArgs = [
        "lsp"
        "stdio"
      ];
      callerProvidesServerArgs = true;
      versionFromMiseTool = "aqua:tamasfe/taplo";
      languages = [ "toml" ];
      notes = "Cursor Even Better TOML already passes `lsp stdio`; Zed can use the configured default args.";
    }
    {
      name = "biome";
      wrapperName = "lspmux-mise-biome";
      provider = "mise";
      server = "biome";
      serverArgs = [ "lsp-proxy" ];
      versionFromMiseTool = "aqua:biomejs/biome";
      languages = [
        "javascript"
        "typescript"
        "json"
        "css"
      ];
    }
  ];

  mkMiseLspmux =
    {
      wrapperName,
      server,
      serverArgs ? [ ],
      callerProvidesServerArgs ? false,
      shell ? null,
      versionFromMiseTool ? null,
      ...
    }:
    let
      serverArgsText = lib.escapeShellArgs serverArgs;
      shellExport = lib.optionalString (shell != null) ''
        export SHELL=${lib.escapeShellArg shell}
      '';
      callerProvidesServerArgsBranch = lib.optionalString callerProvidesServerArgs ''
        if [ "$#" -gt 0 ]; then
          exec "$mise_bin" exec -- ${lib.getExe pkgs.lspmux} client \
            --server-path ${lib.escapeShellArg server} -- "$@"
        fi
      '';
      versionProbe = lib.optionalString (versionFromMiseTool != null) ''
        version="$("$mise_bin" current ${lib.escapeShellArg versionFromMiseTool} 2>/dev/null || true)"
        if [ -n "$version" ]; then
          printf '%s %s\n' ${lib.escapeShellArg server} "$version"
          exit 0
        fi
      '';
    in
    pkgs.writeShellApplication {
      name = wrapperName;
      text = ''
        mise_bin="''${MISE_BIN:-${miseBin}}"
        if [ ! -x "$mise_bin" ]; then
          mise_bin="$(command -v mise || true)"
        fi
        if [ -z "$mise_bin" ]; then
          echo "mise not found; set MISE_BIN or install mise at ${miseBin}" >&2
          exit 127
        fi

        ${miseGuiBootstrap}
        ${shellExport}

        if [ "''${1:-}" = "--version" ] || [ "''${1:-}" = "-V" ]; then
          ${versionProbe}
          exec "$mise_bin" exec -- ${lib.escapeShellArg server} "$@"
        fi

        ${callerProvidesServerArgsBranch}

        exec "$mise_bin" exec -- ${lib.getExe pkgs.lspmux} client \
          --server-path ${lib.escapeShellArg server} -- ${serverArgsText} "$@"
      '';
    };

  mkNixLspmux =
    {
      wrapperName,
      serverPath,
      serverArgs ? [ ],
      ...
    }:
    let
      serverArgsText = lib.escapeShellArgs serverArgs;
    in
    pkgs.writeShellApplication {
      name = wrapperName;
      text = ''
        if [ "''${1:-}" = "--version" ] || [ "''${1:-}" = "-V" ]; then
          exec ${lib.escapeShellArg serverPath} "$@"
        fi

        exec ${lib.getExe pkgs.lspmux} client \
          --server-path ${lib.escapeShellArg serverPath} -- ${serverArgsText} "$@"
      '';
    };

  mkLspmuxWrapper =
    server:
    if server.provider == "nix" then
      mkNixLspmux server
    else if server.provider == "mise" then
      mkMiseLspmux server
    else
      throw "Unsupported lspmux provider: ${server.provider}";

  wrappersByName = lib.listToAttrs (
    map (server: {
      name = server.wrapperName;
      value = mkLspmuxWrapper server;
    }) serverDefinitions
  );

  lspmuxCatalog = {
    version = 1;
    generatedBy = "sharedHome/development/lspmux.nix";
    servers = map (server: {
      inherit (server)
        name
        wrapperName
        provider
        languages
        ;
      server = server.server or server.serverPath;
      serverArgs = server.serverArgs or [ ];
      callerProvidesServerArgs = server.callerProvidesServerArgs or false;
      wrapper = "${profileBin}/${server.wrapperName}";
      miseTool = server.versionFromMiseTool or null;
      notes = server.notes or "";
    }) serverDefinitions;
  };

  elixirLsDebugger = pkgs.writeShellApplication {
    name = "lspmux-mise-elixir-ls-debugger";
    text = ''
      mise_bin="''${MISE_BIN:-${miseBin}}"
      if [ ! -x "$mise_bin" ]; then
        mise_bin="$(command -v mise || true)"
      fi
      if [ -z "$mise_bin" ]; then
        echo "mise not found; set MISE_BIN or install mise at ${miseBin}" >&2
        exit 127
      fi

      ${miseGuiBootstrap}
      export SHELL=/bin/bash
      exec "$mise_bin" exec -- elixir-ls-debugger "$@"
    '';
  };

  cursorElixirLsReleaseShim = pkgs.runCommand "lspmux-mise-elixir-ls-cursor-release-shim" { } ''
    mkdir -p "$out"
    ln -s ${wrappersByName.lspmux-mise-elixir-ls}/bin/lspmux-mise-elixir-ls "$out/language_server.sh"
    ln -s ${elixirLsDebugger}/bin/lspmux-mise-elixir-ls-debugger "$out/debug_adapter.sh"
  '';
in
lib.mkMerge [
  {
    home.packages = [
      pkgs.lspmux
      elixirLsDebugger
    ]
    ++ lib.attrValues wrappersByName;

    xdg.configFile."lspmux/config.toml".text = lspmuxConfig;
    xdg.configFile."lspmux/servers.json".text = "${builtins.toJSON lspmuxCatalog}\n";
    home.file."Library/Application Support/lspmux/config.toml".text = lspmuxConfig;
    home.file."Library/Application Support/lspmux/servers.json".text =
      "${builtins.toJSON lspmuxCatalog}\n";

    home.file.".local/share/lspmux/cursor-elixir-ls-release-shim".source = cursorElixirLsReleaseShim;
  }

  (lib.mkIf pkgs.stdenv.isDarwin {
    launchd.agents.lspmux = {
      enable = true;
      config = {
        Label = "org.codeberg.p2502.lspmux";
        ProgramArguments = [
          "${lib.getExe pkgs.lspmux}"
          "server"
        ];
        EnvironmentVariables = {
          PATH = lib.makeBinPath [
            pkgs.coreutils
            pkgs.lspmux
          ];
          RUST_LOG = "info";
        };
        StandardOutPath = "${config.home.homeDirectory}/Library/Logs/lspmux.log";
        StandardErrorPath = "${config.home.homeDirectory}/Library/Logs/lspmux.log";
        KeepAlive = true;
        RunAtLoad = true;
        LimitLoadToSessionType = [
          "Aqua"
          "Background"
          "LoginWindow"
          "StandardIO"
          "System"
        ];
      };
    };
  })
]
