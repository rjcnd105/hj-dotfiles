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

  enabledApps = filterAttrs (_: app: app.enable) config.homelab.apps;
  ollamaAppList = builtins.attrValues (
    filterAttrs (
      _: app: app.contract.schemaVersion == 2 && app.contract.needs.ollama.models != [ ]
    ) enabledApps
  );

  # app-containers.nix와 같은 규약: 앱 브리지는 br-<name>-<channel>.
  bridgeFor = app: "br-${app.contract.name}-${app.contract.channel}";
in
{
  options.homelab.ollama.enable = mkOption {
    type = types.bool;
    default = ollamaAppList != [ ];
    defaultText = lib.literalMD "`true` when any admitted v2 app lists `needs.ollama.models`";
    description = ''
      Shared Ollama server on the Radeon iGPU (Vulkan) for v2 apps. Models load on
      request and unload when idle, so the server costs no memory between requests.
    '';
  };

  config = mkIf config.homelab.ollama.enable {
    # Mesa RADV Vulkan ICD를 /run/opengl-driver에 둔다. 없으면 ollama가 CPU로 떨어진다.
    hardware.graphics.enable = true;

    services.ollama = {
      enable = true;
      package = pkgs.ollama-vulkan;
      # listen은 0.0.0.0이지만 방화벽이 앱 브리지 인터페이스에만 포트를 연다.
      host = "0.0.0.0";
      port = 11434;
      loadModels = unique (concatMap (app: app.contract.needs.ollama.models) ollamaAppList);
      # 계약에서 빠진 모델은 지워서 디스크에 쌓이지 않게 한다.
      syncModels = true;
      environmentVariables = {
        OLLAMA_VULKAN = "1";
        OLLAMA_IGPU_ENABLE = "1";
        # 요청이 끝나고 2분 뒤 모델을 내려 평소에는 iGPU/RAM을 비운다.
        OLLAMA_KEEP_ALIVE = "2m";
        OLLAMA_MAX_LOADED_MODELS = "1";
        # 한 번에 하나만 돌리고, 대기는 2건까지만 받아 Cloudflare 100초 제한 안에서 끝나게 한다.
        OLLAMA_NUM_PARALLEL = "1";
        OLLAMA_MAX_QUEUE = "2";
        OLLAMA_CONTEXT_LENGTH = "8192";
      };
    };

    networking.firewall.interfaces = builtins.listToAttrs (
      map (app: {
        name = bridgeFor app;
        value.allowedTCPPorts = [ config.services.ollama.port ];
      }) ollamaAppList
    );
  };
}
