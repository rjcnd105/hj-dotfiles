{
  coreutils,
  curl,
  gawk,
  procps,
  writeShellApplication,
}:
writeShellApplication {
  name = "homelab-thermal-alert";
  runtimeInputs = [
    coreutils
    curl
    gawk
    procps
  ];
  text = builtins.readFile ./thermal-alert.sh;
}
