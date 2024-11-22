let
  users = import ./users.nix;
in
{
  hj = {
    hostname = "hj";
    dir = "hj_mac";
    arch = "aarch64-darwin";
    user = users.default;
  };
  gateway = {
    hostname = "gateway";
    dir = "server-nixos-gateway";
    arch = "x86_64-linux";
    user = users.default;
  };
}
