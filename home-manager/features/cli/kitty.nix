{
  programs.kitty = {
    enable = true;

    settings = {
      # 폰트 설정 - oh-my-zsh 테마와 아이콘을 위해
      font_family = "JetBrainsMono";
      font_size = 13;
      adjust_line_height = 115;  # oh-my-zsh 프롬프트가 더 잘 보이도록
      modify_font = "cell_height 2px";

      # Zellij 통합을 위한 설정
      shell = "zsh";  # zsh 기본 실행
      allow_remote_control = "yes";  # Zellij 제어 허용
      listen_on = "unix:/tmp/kitty";
      enabled_layouts = "tall,stack,grid";  # Zellij 레이아웃과 호환되는 레이아웃

      # 성능 설정
      repaint_delay = 8;
      input_delay = 2;
      sync_to_monitor = true;

      # Zellij 상태바와의 조화를 위한 설정
      window_padding_width = 4;
      hide_window_decorations = "titlebar-only";  # Zellij UI가 더 잘 보이도록

      # 터미널 설정
      scrollback_lines = 10000;  # Zellij의 scroll_buffer_size와 맞춤
      copy_on_select = "clipboard";
      strip_trailing_spaces = "smart";

      # 알림 설정 (oh-my-zsh command-not-found와 연동)
      enable_audio_bell = false;
      visual_bell_duration = 0.1;
      window_alert_on_bell = true;

      # macOS 특화 설정
      macos_option_as_alt = "yes";  # Alt 키바인딩을 위해
      macos_quit_when_last_window_closed = "yes";
      macos_show_window_title_in = "none";

      # URL 처리 (git 링크 등을 위해)
      url_style = "curly";
      detect_urls = "yes";
      url_prefixes = "http https file ftp git";

      # Catppuccin 테마와 어울리는 설정
      background_opacity = 1.0;
      dynamic_background_opacity = "yes";

      # 탭바 설정 (Zellij가 주로 관리하므로 최소화)
      tab_bar_edge = "top";
      tab_bar_style = "hidden";
    };

    # 키바인딩 (Zellij와 충돌 방지)
    keybindings = {
      # Kitty의 기본 키바인딩 중 Zellij와 충돌하는 것들 비활성화
      "cmd+w" = "no_op";  # Zellij의 Alt+w와 충돌 방지
      "cmd+t" = "no_op";  # Zellij의 Alt+n과 충돌 방지
      "cmd+enter" = "no_op";  # Zellij의 Alt+f와 충돌 방지

      # 유용한 Kitty 전용 키바인딩
      "cmd+equal" = "change_font_size all +1.0";
      "cmd+minus" = "change_font_size all -1.0";
      "cmd+0" = "change_font_size all 0";
      "cmd+c" = "copy_to_clipboard";
      "cmd+v" = "paste_from_clipboard";
    };

  };

  home.sessionVariables = {
    TERMINAL = "kitty";
    DEFAULT_TERMINAL = "kitty";
  };
}
