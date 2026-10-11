{
  config,
  lib,
  pkgs,
  myOptions,
  ...
}:
let

  mkAddFileAttrIfExists =
    name:
    let
      filePath = myOptions.paths.files + "/${myOptions.filesHost}/${name}";
    in
    lib.optionalAttrs (builtins.pathExists filePath) {
      "${name}" = {
        source = filePath;
        force = true;
      };
    };

  # files/${hosts}내의 각 폴더를 home.file 형식으로 outOfStore Symlink로 매핑
  mkLinkFolders =
    {
      scanPath, # Nix path — builtins.readDir용 (pure mode 호환)
      linkPath, # string — mkOutOfStoreSymlink 대상 경로
      namePath ? null,
      userPath ? config.home.homeDirectory,
    }:
    let
      currentScanPath = (if namePath == null then scanPath else (scanPath + "/${namePath}"));
      currentLinkPath = (if namePath == null then linkPath else (linkPath + "/${namePath}"));
    in
    (lib.foldlAttrs (
      acc: currentName: value:
      let
        childPath = (if namePath == null then currentName else (namePath + "/${currentName}"));
        scanFile = scanPath + "/${childPath}";
        linkFile = linkPath + "/${childPath}";
        # .manual-link 파일이 있으면 "통째로 링크할 디렉토리"로 판단
        isManualLinkDir = value == "directory" && builtins.pathExists (scanFile + "/.manual-link");
      in
      # 심볼릭 링크이거나 .manual-link 마커가 있는 폴더인 경우 스킵
      if value == "symlink" then
        acc
      # .manual-link가 발견되면 재귀를 멈추고 폴더 자체를 링크함
      else if isManualLinkDir then
        acc
        // {
          "${childPath}" = {
            source = config.lib.file.mkOutOfStoreSymlink linkFile;
            force = true; # 기존 디렉토리가 있어도 강제로 덮어쓰고 링크로 대체
          };
        }
      else if value == "directory" then
        acc
        // (mkLinkFolders {
          inherit scanPath linkPath userPath;
          namePath = childPath;
        })
      else
        acc
        // {
          "${childPath}" = {
            source = config.lib.file.mkOutOfStoreSymlink linkFile;
            recursive = true;
            force = true;
          };
        }
    ) { } (builtins.readDir currentScanPath));

  # Nix path — store로 복사되어 pure evaluation에서 builtins.readDir 가능
  scanBasePath = ../files + "/${myOptions.filesHost}";
  # String path — 실제 파일시스템 경로, mkOutOfStoreSymlink 대상
  linkBasePath = myOptions.absoluteProjectPath + "/files/${myOptions.filesHost}";

  # 로그인 직후 macOS가 Ghostty를 다시 열 때 암호화된 Nix Store 볼륨은 아직 마운트 전일 수 있다.
  # home.file 링크는 /nix/store를 거치므로 그 순간 끊겨 Ghostty가 설정 없이 기본 셸(zsh)로 뜬다.
  # Ghostty가 읽는 설정과 command wrapper만 store를 거치지 않고 repo 파일을 직접 가리키게 한다.
  # { "~/ 기준 링크 경로" = "files/${filesHost} 기준 원본 경로"; }
  ghosttyDirectLinks =
    lib.optionalAttrs
      (
        pkgs.stdenv.hostPlatform.isDarwin
        && builtins.pathExists (scanBasePath + "/.config/ghostty/config.ghostty")
      )
      {
        ".config/ghostty/config.ghostty" = ".config/ghostty/config.ghostty";
        ".config/ghostty/ghostty-nix-env.sh" = ".config/ghostty/ghostty-nix-env.sh";
      };

in
{

  # TODO: 추후 XDG_CONFIG를 지원하지 않는 앱(ex: cursor) 등을 위해 특정 위치(ex: ~/Library/Application Support)에 2차 심볼릭 링크 체인 거는 기능 추가
  home.preferXdgDirectories = true;
  xdg.enable = true;
  # ${PROJECT_ROOT}/files/${hostName} 내의 모든 파일/폴더를 ~/ 기준으로 매핑
  home.file = removeAttrs (mkLinkFolders {
    scanPath = scanBasePath;
    linkPath = linkBasePath;
  }) (builtins.attrNames ghosttyDirectLinks);

  home.activation.linkGhosttyDirect = lib.mkIf (ghosttyDirectLinks != { }) (
    lib.hm.dag.entryAfter [ "linkGeneration" ] (
      lib.concatStrings (
        lib.mapAttrsToList (
          target: source:
          let
            targetPath = "${config.home.homeDirectory}/${target}";
          in
          ''
            run mkdir -p ${lib.escapeShellArg (dirOf targetPath)}
            run ln -sfn ${lib.escapeShellArg "${linkBasePath}/${source}"} ${lib.escapeShellArg targetPath}
          ''
        ) ghosttyDirectLinks
      )
    )
  );

}
