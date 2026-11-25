{ pkgs, ... }:
let
  vcsKind = pkgs.writeShellScriptBin "vcs-kind" ''
    if ${pkgs.jujutsu}/bin/jj root >/dev/null 2>&1; then
      printf 'jj\n'
    else
      printf 'git\n'
    fi
  '';
in
{
  home.packages = [
    pkgs.jujutsu
    vcsKind
  ];
}
