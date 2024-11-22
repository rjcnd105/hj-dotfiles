{ pkgs, ... }:
{
  home.packages = with pkgs; [
    ansible

    docker-compose

    teleport
    argocd
    fluxcd
    vault
    supabase-cli
    awscli2
    redis
    colmena
  ];
}
