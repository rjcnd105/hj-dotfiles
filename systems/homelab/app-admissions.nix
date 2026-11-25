{ inputs, lib, ... }:
let
  admission =
    channel: import "${inputs.deopjibApp}/deopjib/devops/homelab-admission.nix" { inherit channel; };
  releaseManifestOrigins = [ "https://github.com/rjcnd105/my-app" ];
in
{
  homelab.apps =
    import ./admit-app.nix {
      inherit lib releaseManifestOrigins;
      admission = admission "dev";
      host = {
        subnetId = 10;
        postgresPasswordSecret = "DEOPJIB_DEV_POSTGRES_PASSWORD";
      };
    }
    // import ./admit-app.nix {
      inherit lib releaseManifestOrigins;
      admission = admission "prod";
      host = {
        subnetId = 11;
        postgresPasswordSecret = "DEOPJIB_PROD_POSTGRES_PASSWORD";
      };
    }
    // import ./admit-app.nix {
      inherit lib;
      admission = import "${inputs.frontVibeHelperApp}/devops/homelab-admission.nix";
      releaseManifestOrigins = [ "https://github.com/rjcnd105/front-vibe-helper" ];
      host.subnetId = 12;
    };
}
