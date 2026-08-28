# v2 admission 헬퍼: 앱 레포가 제안한 { key, app }에 호스트 정책을 얹는다.
# 사용 예:
#   homelab.apps = import ./admit-app.nix {
#     admission = import "${inputs.myApp}/devops/homelab-admission.nix";
#     releaseManifestOrigins = [ "https://github.com/example/my-app" ];
#     host = {
#       subnetId = 7;
#       postgresPasswordSecret = "MY_APP_DEV_PG_PASSWORD";
#     };
#   };
{
  admission,
  releaseManifestOrigins,
  host ? { },
}:
{
  ${admission.key} = admission.app // {
    host = admission.app.host // { inherit releaseManifestOrigins; } // host;
  };
}
