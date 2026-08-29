# v2 admission 헬퍼: 앱 레포가 제안한 { key, app }에 호스트 정책을 얹는다.
# 사용 예:
#   homelab.apps = import ./admit-app.nix {
#     inherit lib;
#     admission = import "${inputs.exampleApp}/devops/homelab-admission.nix";
#     releaseManifestOrigins = [ "https://github.com/OWNER/example-app" ];
#     host = {
#       subnetId = 7;
#       postgresPasswordSecret = "EXAMPLE_DEV_PG_PASSWORD";
#     };
#   };
{
  lib,
  admission,
  releaseManifestOrigins,
  host ? { },
}:
{
  ${admission.key} = admission.app // {
    # 호스트 정책은 recursiveUpdate로 얹는다. `//`면 host.volumes/secretMap 같은
    # 중첩 속성을 통째로 덮어써 앱이 선언한 항목이 조용히 사라진다.
    host = lib.recursiveUpdate (admission.app.host // { inherit releaseManifestOrigins; }) host;
  };
}
