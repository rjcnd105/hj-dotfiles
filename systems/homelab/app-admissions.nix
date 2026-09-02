{ inputs, lib, ... }:
let
  # 앱 레포 admission은 { channel } 함수. 채널마다 한 번씩 admit한다.
  admission =
    channel: import "${inputs.deopjibApp}/deopjib/devops/homelab-admission.nix" { inherit channel; };
  releaseManifestOrigins = [ "https://github.com/rjcnd105/my-app" ];
in
{
  homelab.apps =
    # dev — dev.deopjib.site
    import ./admit-app.nix {
      inherit lib releaseManifestOrigins;
      admission = admission "dev";
      host = {
        # 10.90.<subnetId>.0/24 — 앱별 유일. 게이트웨이 10.90.10.1이 공유 PG 접점.
        subnetId = 10;
        postgresPasswordSecret = "DEOPJIB_DEV_POSTGRES_PASSWORD";
      };
    }
    # prod — app.deopjib.site (승인 배포 채널)
    // import ./admit-app.nix {
      inherit lib releaseManifestOrigins;
      admission = admission "prod";
      host = {
        subnetId = 11;
        postgresPasswordSecret = "DEOPJIB_PROD_POSTGRES_PASSWORD";
      };
    };
}
