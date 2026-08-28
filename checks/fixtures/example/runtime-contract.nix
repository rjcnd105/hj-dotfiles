# 계약 v2 픽스처: PORT(=3000) 리슨, /data 단일 마운트, needs.postgres 컨벤션.
# 실제 앱 레포의 devops/runtime-contract.nix가 따라야 할 모양의 기준 예시다.
{ channel, domain }:
let
  imageTag = "${channel}-current";
in
{
  schemaVersion = 2;
  name = "example";
  inherit channel;

  needs.postgres = true;

  images.app = "ghcr.io/example/example:${imageTag}";

  services.app = {
    image = "app";
    healthPath = "/health";
    updatePolicy = "manual";
    volumeMounts = [
      {
        volume = "data";
        mountPath = "/data";
      }
    ];
  };

  routes = [
    {
      host = domain;
      path = "/";
      service = "app";
    }
  ];

  release = {
    manifestUrl = "https://github.com/example/example/releases/download/{target}/release.json";
    channels.${channel} = {
      tag = imageTag;
      targetPattern = "^example-v.*$";
      smokePaths = [ "/health" ];
    };
  };

  volumes.data.notes = "Example app data, mounted at /data.";
}
