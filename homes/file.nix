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

  # files/${hosts}내의 각 폴더를 home.file 형식으로 매핑
  mkLinkFolders =
    {
      basePath,
      namePrefix ? "",
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
      in

      if value == "directory" then
        acc
        // (mkLinkFolders {
          inherit basePath userPath;
          namePath = childPath;
        })
      else
        acc
        // {
          "${namePrefix}${childPath}" = {
            source = config.lib.file.mkOutOfStoreSymlink currentFile;
            force = true;
          };
        }
    ) { } (builtins.readDir currentPath));

in
{

  home.preferXdgDirectories = true;
  xdg.enable = true;
  xdg.configFile = (
    mkLinkFolders {
      basePath = myOptions.absoluteProjectPath + "/files/${myOptions.hostName}/.config";
      userPath = config.home.homeDirectory + "/.config";
    }
  );
  home.file = (mkAddFileAttrIfExists ".editorconfig");

}
