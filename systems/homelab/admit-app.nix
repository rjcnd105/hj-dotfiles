{
  lib,
  admission,
  releaseManifestOrigins,
  host ? { },
}:
{
  ${admission.key} = admission.app // {
    host = lib.recursiveUpdate (admission.app.host // { inherit releaseManifestOrigins; }) host;
  };
}
