{ inputs, ... }:
let
  deopjibAdmissionSource = "${inputs.deopjibRuntime}/deopjib/devops/homelab-admission.nix";
  deopjibRuntimeContractSource = "${inputs.deopjibRuntime}/deopjib/devops/runtime-contract.nix";
  deopjibManifestSchemaSource = "${inputs.deopjibRuntime}/deopjib/devops/release-manifest.schema.json";
  deopjibManifestGeneratorSource = "${inputs.deopjibRuntime}/scripts/deopjib-generate-release-manifest";
  deopjibAdmission = import deopjibAdmissionSource;
in
{
  homelab.apps.${deopjibAdmission.key} = deopjibAdmission.app // {
    runtimeContractSourceSha256 = builtins.hashFile "sha256" deopjibRuntimeContractSource;
    homelabAdmissionSourceSha256 = builtins.hashFile "sha256" deopjibAdmissionSource;
    manifestSchemaSourceSha256 = builtins.hashFile "sha256" deopjibManifestSchemaSource;
    manifestGeneratorSourceSha256 = builtins.hashFile "sha256" deopjibManifestGeneratorSource;
    host = deopjibAdmission.app.host // {
      releaseManifestOrigins = [ "https://github.com/rjcnd105/my-app" ];
    };
  };
}
