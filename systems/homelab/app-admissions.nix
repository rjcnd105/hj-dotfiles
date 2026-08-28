{ inputs, ... }:
{
  homelab.apps = import ./admit-app.nix {
    admission = import "${inputs.deopjibRuntime}/deopjib/devops/homelab-admission.nix";
    releaseManifestOrigins = [ "https://github.com/rjcnd105/my-app" ];
    host = {
      # 10.90.<subnetId>.0/24 — 앱별 유일. 게이트웨이 10.90.10.1이 공유 PG 접점.
      subnetId = 10;
      postgresPasswordSecret = "DEOPJIB_DEV_POSTGRES_PASSWORD";
    };
  };
}
