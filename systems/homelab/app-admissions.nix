{ inputs, ... }:
let
  deopjibAdmission = import "${inputs.deopjibRuntime}/deopjib/devops/homelab-admission.nix";
in
{
  homelab.apps.${deopjibAdmission.key} = deopjibAdmission.app;
}
