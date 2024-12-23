# pkgs/aqua/default.nix
{
  lib,
  stdenv,
  fetchurl,
  installShellFiles,
  system,
}:

let
  # GitHub API를 통해 최신 릴리스 정보를 가져옵니다
  latestRelease = builtins.fromJSON (
    builtins.readFile (
      builtins.fetchurl {
        url = "https://api.github.com/repos/aquaproj/aqua/releases/latest";
        # GitHub API는 rate limiting이 있어서 자주 호출하면 문제가 될 수 있습니다
      }
    )
  );

  version = lib.removePrefix "v" latestRelease.tag_name;

  # 시스템에 따른 플랫폼 선택
  platform =
    if system == "x86_64-darwin" then
      "darwin"
    else if system == "aarch64-darwin" then
      "darwin_arm64"
    else if system == "x86_64-linux" then
      "linux"
    else
      throw "Unsupported platform: ${system}";

  # 다운로드 URL 구성
  url = "https://github.com/aquaproj/aqua/releases/download/v${version}/aqua_${version}_${platform}_amd64.tar.gz";

  # 실제 바이너리 다운로드
  src = fetchurl {
    inherit url;
    # fetchurl이 자동으로 해시를 계산합니다
    sha256 = ""; # 처음에는 비워두고, 에러 메시지에서 올바른 해시를 복사합니다
  };

in
stdenv.mkDerivation {
  pname = "aqua";
  inherit version;
  inherit src;

  nativeBuildInputs = [ installShellFiles ];

  sourceRoot = ".";

  installPhase = ''
    mkdir -p $out/bin
    cp aqua $out/bin/
    chmod +x $out/bin/aqua

    # shell completion 설치
    installShellCompletion --cmd aqua \
      --bash <($out/bin/aqua completion bash) \
      --fish <($out/bin/aqua completion fish) \
      --zsh <($out/bin/aqua completion zsh)
  '';

  meta = with lib; {
    description = "Declarative CLI Version Manager";
    homepage = "https://github.com/aquaproj/aqua";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.unix;
  };
}
