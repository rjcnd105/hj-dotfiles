{
  pkgs,
}:
let
  version = "2.40.0";
  sha256 = "sha256-aFyxwl1QmCgacOfWhKca5vjOT1SayLwLnW1FUyQssX8=";
in
# aqua
pkgs.stdenv.mkDerivation {
  version = version;

  name = "aqua";
  src = pkgs.fetchurl {
    url = "https://github.com/aquaproj/aqua/releases/download/v${version}/aqua_darwin_arm64.tar.gz";
    sha256 = sha256;
  };

  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/bin
    cp -r aqua $out/bin
  '';

  meta = {
    inherit version;
    description = "Declarative CLI Version manager written in Go. Support Lazy Install, Registry, and continuous update with Renovate. CLI version is switched seamlessly";
    homepage = "https://github.com/aquaproj/aqua";
    license = pkgs.lib.licenses.mit;
  };
}
