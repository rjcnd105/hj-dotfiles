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
        matchUserFile = userPath + "${userPath}/${childPath}";
        # 디렉토리 내에 .manual-link 마커 파일이 있으면 수동 링크 폴더로 간주
        isManualLinkDir = value == "directory" && builtins.pathExists (currentFile + "/.manual-link");
      in

      # 심볼릭 링크이거나 .manual-link 마커가 있는 폴더인 경우 스킵
      if value == "symlink" then
        acc
      else if isManualLinkDir then
        acc
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
            force = true;
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
