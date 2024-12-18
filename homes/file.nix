{
  config,
  lib,
  pkgs,
  myOptions,
  ...
}:
let
  # hostfolder = myOptions.paths.files + "/${myOptions.hostName}";

  getFolderAttrs = host: builtins.readDir (myOptions.paths.files + "/${host}");

  # files/${hosts}내의 각 폴더를 home.file 형식으로 매핑
  getHomeFolders =
    host:
    (lib.foldlAttrs (
      acc: name: value:
      if value == "directory" then
        acc
        // {
          "${name}" = {
            recursive = true;
            source = myOptions.paths.files + "/${host}/${name}";
          };
        }
      else
        acc
        // {
          "${name}" = {
            source = myOptions.paths.files + "/${host}/${name}";
          };
        }
    ) { } (getFolderAttrs host));
in
{

  # home.file = {
  # cache = {
  #   enable = true;
  #   recursive = true;
  # };
  # config = {
  #   enable = true;
  #   recursive = true;
  # };
  # data = {
  #   enable = true;
  #   recursive = true;
  #   userOnly = true;
  # };
  # state = {
  #   enable = true;
  #   recursive = true;
  # };
  # };

  # home.sessionVariables = {

  #   # APPS_DIR = "${homedir}/.local/apps";
  #   # SYNC_DIR = "${homedir}/.local/sync";
  #   # LAUNCHERS_DIR = "${dataHome}/applications";
  #   # UNITS_DIR = "${configHome}/systemd";
  #   # BIN_DIR = "${homedir}/.local/bin";
  #   # SCRIPTS_DIR = "${homedir}/.local/scripts";
  #   # SECRETS_DIR = "${homedir}/.local/secrets";
  #   # AUTOSTART_DIR = "${dataHome}/autostart";
  # };
  #
  #

  home.file = (getHomeFolders myOptions.hostName);

}
