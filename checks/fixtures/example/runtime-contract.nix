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
