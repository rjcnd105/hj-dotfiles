{ inputs, lib, ... }:
let
  deopjibAdmission = import "${inputs.deopjibRuntime}/deopjib/devops/homelab-admission.nix";
in
{
  # The original April network cannot be updated in place; a new name forces
  # Podman to create clean netavark and aardvark state without touching volumes.
  homelab.apps.${deopjibAdmission.key} = lib.recursiveUpdate deopjibAdmission.app {
    host.networkName = "deopjib-dev-v2";
  };
}
