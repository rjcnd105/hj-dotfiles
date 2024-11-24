let
  users = import ./users.nix;
in
{
  workspace = {
    hostname = "workspace";
    dir = "workspace";
    arch = "aarch64-darwin";
    user = users.default;
  };
}
