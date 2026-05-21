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

in
{

  # TODO: 추후 XDG_CONFIG를 지원하지 않는 앱(ex: cursor) 등을 위해 특정 위치(ex: ~/Library/Application Support)에 2차 심볼릭 링크 체인 거는 기능 추가
  home.preferXdgDirectories = true;
  xdg.enable = true;
  # ${PROJECT_ROOT}/files/${hostName} 내의 모든 파일/폴더를 ~/ 기준으로 매핑
  home.file =
    let
      # Nix path — store로 복사되어 pure evaluation에서 builtins.readDir 가능
      scanBasePath = ../files + "/${myOptions.filesHost}";
      # String path — 실제 파일시스템 경로, mkOutOfStoreSymlink 대상
      linkBasePath = myOptions.absoluteProjectPath + "/files/${myOptions.filesHost}";
    in
    (mkLinkFolders {
      scanPath = scanBasePath;
      linkPath = linkBasePath;
    })
    //
      lib.optionalAttrs
        (pkgs.stdenv.isDarwin && builtins.pathExists (scanBasePath + "/.config/ghostty/config"))
        {
          "Library/Application Support/com.mitchellh.ghostty/config" = {
            source = config.lib.file.mkOutOfStoreSymlink (linkBasePath + "/.config/ghostty/config");
            force = true;
          };
        };

}
