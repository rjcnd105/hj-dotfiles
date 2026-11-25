{
  config,
  lib,
  pkgs,
  ...
}:
let
  inherit (lib)
    concatMap
    filterAttrs
    mkIf
    mkOption
    types
    unique
    ;

  conventions = import ./app-conventions.nix { inherit lib; };
  inherit (conventions) bridgeInterfaceFor usesSharedOllama;

  enabledApps = filterAttrs (_: app: app.enable) config.homelab.apps;
  ollamaAppList = builtins.attrValues (filterAttrs (_: usesSharedOllama) enabledApps);
in
{
  options.homelab.ollama.enable = mkOption {
    type = types.bool;
    default = ollamaAppList != [ ];
    defaultText = lib.literalMD "`true` when any admitted app lists `needs.ollama.models`";
    description = ''
      Shared Ollama server on the Radeon iGPU (Vulkan) for admitted apps. Models load on
      request and unload when idle, so the server costs no memory between requests.
    '';
  };

  config = mkIf config.homelab.ollama.enable {
    # Mesa RADV Vulkan ICD를 /run/opengl-driver에 둔다. 없으면 ollama가 CPU로 떨어진다.
    hardware.graphics.enable = true;

    services.ollama = {
      enable = true;
      package = pkgs.ollama-vulkan;
      host = "0.0.0.0";
      port = 11434;
      loadModels = unique (concatMap (app: app.contract.needs.ollama.models) ollamaAppList);
      syncModels = true;
      environmentVariables = {
        OLLAMA_VULKAN = "1";
        OLLAMA_IGPU_ENABLE = "1";
        OLLAMA_KEEP_ALIVE = "2m";
        OLLAMA_MAX_LOADED_MODELS = toString (
          lib.foldl' lib.max 1 (map (app: lib.length app.contract.needs.ollama.models) ollamaAppList)
        );
        # 한 번에 하나만 돌리고, 대기는 2건까지만 받아 Cloudflare 100초 제한 안에서 끝나게 한다.
        OLLAMA_NUM_PARALLEL = "1";
        OLLAMA_MAX_QUEUE = "2";
        OLLAMA_CONTEXT_LENGTH = "8192";
      };
    };

    networking.firewall.interfaces = builtins.listToAttrs (
      map (app: {
        name = bridgeInterfaceFor app;
        value.allowedTCPPorts = [ config.services.ollama.port ];
      }) ollamaAppList
    );
  };
}
