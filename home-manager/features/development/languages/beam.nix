{ pkgs, ... }:
{
  home.packages = with pkgs; [
    # Erlang
    erlang
    erlang-ls    # LSP 지원
    rebar3

    # Elixir
    elixir
    elixir-ls    # LSP 지원

    # Gleam
    gleam
  ];

  # 환경 변수 설정
  home.sessionVariables = {
    MIX_HOME = "$HOME/.mix";
    HEX_HOME = "$HOME/.hex";
  };


  # Mix 설정 파일
  home.file = {
    ".mix/config.exs".text = ''
      import Config

      config :mix_tasks,
        default_task: "test",
        preferred_cli_env: [
          coveralls: :test,
          "coveralls.detail": :test,
          "coveralls.post": :test,
          "coveralls.html": :test
        ]

      config :hex,
        offline: false,
        unsafe_https: false,
        unsafe_registry: false
    '';

    # IEx 설정
    ".iex.exs".text = ''
      IEx.configure(
        colors: [
          eval_result: [:green, :bright],
          eval_error: [:red, :bright],
          eval_info: [:yellow, :bright],
        ],
        default_prompt:
          "#{IO.ANSI.green}%prefix#{IO.ANSI.reset}" <>
          "(#{IO.ANSI.cyan}%counter#{IO.ANSI.reset})" <>
          "#{IO.ANSI.bright_black}|>#{IO.ANSI.reset}",
        alive_prompt:
          "#{IO.ANSI.green}%prefix#{IO.ANSI.reset}" <>
          "(#{IO.ANSI.cyan}%node#{IO.ANSI.reset})" <>
          "#{IO.ANSI.bright_black}|>#{IO.ANSI.reset}"
      )
    '';
  }
}
