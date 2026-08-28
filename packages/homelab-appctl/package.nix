{
  lib,
  buildGoModule,
  makeWrapper,
  coreutils,
  podman,
  systemd,
  githubTokenFile ? null,
}:
buildGoModule {
  pname = "homelab-appctl";
  version = "2.0.0";

  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./go.mod
      (lib.fileset.fileFilter (file: file.hasExt "go") ./.)
    ];
  };

  # 외부 Go 의존성 없음 (stdlib 전용).
  vendorHash = null;

  nativeBuildInputs = [ makeWrapper ];

  # 런타임 도구는 호출 환경 PATH에 의존하지 않도록 wrapper로 고정한다.
  postInstall = ''
    wrapProgram $out/bin/homelab-appctl \
      --prefix PATH : ${
        lib.makeBinPath [
          coreutils
          podman
          systemd
        ]
      } ${
        lib.optionalString (
          githubTokenFile != null
        ) "--set-default HOMELAB_APPCTL_GITHUB_TOKEN_FILE ${lib.escapeShellArg githubTokenFile}"
      }
  '';

  meta = {
    description = "nix-dots homelab app release deploy adapter";
    mainProgram = "homelab-appctl";
  };
}
