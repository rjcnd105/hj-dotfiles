{ lib }:
let
  unitPrefixFor = app: "${app.contract.name}-${app.contract.channel}";
  bridgeInterfaceFor = app: "br-${unitPrefixFor app}";
  sharedPostgresNameFor =
    app: lib.replaceStrings [ "-" ] [ "_" ] "${app.contract.name}_${app.contract.channel}";
  appSubnetFor = app: "10.90.${toString app.host.subnetId}.0/24";
  appGatewayFor = app: "10.90.${toString app.host.subnetId}.1";
  usesSharedPostgres = app: app.contract.needs.postgres;
  usesSharedOllama = app: app.contract.needs.ollama.models != [ ];
in
{
  inherit
    unitPrefixFor
    bridgeInterfaceFor
    sharedPostgresNameFor
    appSubnetFor
    appGatewayFor
    usesSharedPostgres
    usesSharedOllama
    ;
}
