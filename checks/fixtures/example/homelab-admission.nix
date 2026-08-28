let
  runtimeContract = ./runtime-contract.nix;
in
{
  key = "example";

  app = {
    enable = true;
    contract = import runtimeContract {
      channel = "dev";
      domain = "dev.example.test";
    };
    host = {
      domain = "dev.example.test";
      loopbackPortBase = 18200;
      volumes.data = { };
    };
  };
}
