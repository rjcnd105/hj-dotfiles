{
  lib,
  buildGoModule,
  makeWrapper,
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

  vendorHash = null;

  nativeBuildInputs = [ makeWrapper ];

  postInstall = ''
    wrapProgram $out/bin/homelab-appctl \
      --prefix PATH : ${
        lib.makeBinPath [
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
