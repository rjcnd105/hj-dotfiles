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
      filePath = myOptions.paths.files + "/${myOptions.hostName}/${name}";
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
      basePath,
      namePath ? null,
      userPath ? config.home.homeDirectory,
    }:
    let
      currentPath = (if namePath == null then basePath else (basePath + "/${namePath}"));
    in
    (lib.foldlAttrs (
      acc: currentName: value:
      let
        childPath = (if namePath == null then currentName else (namePath + "/${currentName}"));
        currentFile = basePath + "/${childPath}";
        # .manual-link 파일이 있으면 "통째로 링크할 디렉토리"로 판단
        isManualLinkDir = value == "directory" && builtins.pathExists (currentFile + "/.manual-link");
      in
      # 심볼릭 링크이거나 .manual-link 마커가 있는 폴더인 경우 스킵
      if value == "symlink" then
        acc
      # .manual-link가 발견되면 재귀를 멈추고 폴더 자체를 링크함
      else if isManualLinkDir then
        acc // {
          "${childPath}" = {
            source = config.lib.file.mkOutOfStoreSymlink currentFile;
            force = true; # 기존 디렉토리가 있어도 강제로 덮어쓰고 링크로 대체
          };
        }
      else if value == "directory" then
        acc
        // (mkLinkFolders {
          inherit basePath userPath;
          namePath = childPath;
        })
      else
        acc
        // {
          "${childPath}" = {
            source = config.lib.file.mkOutOfStoreSymlink currentFile;
            recursive = true;
          };
        }
    ) { } (builtins.readDir currentPath));

in
{

  # TODO: 추후 XDG_CONFIG를 지원하지 않는 앱(ex: cursor) 등을 위해 특정 위치(ex: ~/Library/Application Support)에 2차 심볼릭 링크 체인 거는 기능 추가
  home.preferXdgDirectories = true;
  xdg.enable = true;
  # ${PROJECT_ROOT}/files/config/~ 내에 있는 파일들을 host별 매핑
  xdg.configFile =
    let
      initalBasePath = myOptions.absoluteProjectPath + "/files/${myOptions.hostName}/.config";
    in
    (mkLinkFolders {
      basePath = initalBasePath;
      userPath = config.home.homeDirectory + "/.config";
    });

  home.file = (mkAddFileAttrIfExists ".editorconfig");

}
