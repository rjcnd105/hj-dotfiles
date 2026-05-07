{
  config,
  lib,
  pkgs,
  ...
}:
let
  miseBin = "/opt/homebrew/bin/mise";

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
      "LOGNAME",
      "SHELL",
      "TMPDIR",
      "LANG",
      "LC_*",
      "XDG_*",
      "MISE_BIN",
      "MISE_*",
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

  mkMiseLspmux =
    {
      name,
      server,
      serverArgs ? [ ],
      versionFromMiseTool ? null,
    }:
    let
      serverArgsText = lib.escapeShellArgs serverArgs;
      versionProbe = lib.optionalString (versionFromMiseTool != null) ''
        version="$("$mise_bin" current ${lib.escapeShellArg versionFromMiseTool} 2>/dev/null || true)"
        if [ -n "$version" ]; then
          printf '%s %s\n' ${lib.escapeShellArg server} "$version"
          exit 0
        fi
      '';
    in
    pkgs.writeShellApplication {
      name = "lspmux-mise-${name}";
      text = ''
        mise_bin="''${MISE_BIN:-${miseBin}}"
        if [ ! -x "$mise_bin" ]; then
          mise_bin="$(command -v mise || true)"
        fi
        if [ -z "$mise_bin" ]; then
          echo "mise not found; set MISE_BIN or install mise at ${miseBin}" >&2
          exit 127
        fi

        if [ "''${1:-}" = "--version" ] || [ "''${1:-}" = "-V" ]; then
          ${versionProbe}
          exec "$mise_bin" exec -- ${lib.escapeShellArg server} "$@"
        fi

        exec "$mise_bin" exec -- ${lib.getExe pkgs.lspmux} client \
          --server-path ${lib.escapeShellArg server} -- ${serverArgsText} "$@"
      '';
    };

  elixirLs = mkMiseLspmux {
    name = "elixir-ls";
    server = "elixir-ls";
    versionFromMiseTool = "elixir-ls";
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

      exec "$mise_bin" exec -- elixir-ls-debugger "$@"
    '';
  };

  expert = mkMiseLspmux {
    name = "expert";
    server = "expert";
  };

  rustAnalyzer = mkMiseLspmux {
    name = "rust-analyzer";
    server = "rust-analyzer";
  };

  cursorElixirLsReleaseShim = pkgs.runCommand "lspmux-mise-elixir-ls-cursor-release-shim" { } ''
    mkdir -p "$out"
    ln -s ${elixirLs}/bin/lspmux-mise-elixir-ls "$out/language_server.sh"
    ln -s ${elixirLsDebugger}/bin/lspmux-mise-elixir-ls-debugger "$out/debug_adapter.sh"
  '';
in
lib.mkMerge [
  {
    home.packages = [
      pkgs.lspmux
      elixirLs
      elixirLsDebugger
      expert
      rustAnalyzer
    ];

    xdg.configFile."lspmux/config.toml".text = lspmuxConfig;

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
