{
  programs.kitty = {
    enable = true;
    shellIntegration = {
      enableZshIntegration = true;
    };
    settings = {
      # 폰트 설정 - oh-my-zsh 테마와 아이콘을 위해`
      font_family = "JetBrainsMono Nerd Font SemiLight";
      font_size = 11;
      adjust_line_height = 12;  # oh-my-zsh 프롬프트가 더 잘 보이도록
      bold_font = "JetBrainsMono Nerd Font Medium";

      allow_remote_control = "yes";  # Zellij 제어 허용
      listen_on = "unix:/tmp/kitty";

      # Zellij 상태바와의 조화를 위한 설정
      window_padding_width = 8;
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

      # URL 처리 (git 링크 등을 위해)
      detect_urls = "yes";

      # Catppuccin 테마와 어울리는 설정
      background_opacity = 0.95;
      dynamic_background_opacity = "yes";

      tab_bar_style = "powerline";
      tab_title_template = " {index}:{fmt.fg.tab}{$(basename $tab.active_wd)} ";
    };

    # 키바인딩 (Zellij와 충돌 방지)
    keybindings = {
      # 유용한 Kitty 전용 키바인딩
      "cmd+equal" = "change_font_size all +1.0";
      "cmd+minus" = "change_font_size all -1.0";
      "cmd+]" = "move_tab_forward";
      "cmd+[" = "move_tab_backward";

      "cmd+0" = "change_font_size all 0";
      "cmd+c" = "copy_to_clipboard";
      "cmd+v" = "paste_from_clipboard";
      "cmd+1" = "goto_tab 1";
      "cmd+2" = "goto_tab 2";
      "cmd+3" = "goto_tab 3";
      "cmd+4" = "goto_tab 4";
      "cmd+5" = "goto_tab 5";
      "cmd+6" = "goto_tab 6";
      "cmd+7" = "goto_tab 7";
      "cmd+8" = "goto_tab 8";
      "cmd+9" = "goto_tab 9";
      "cmd+k" = "clear_terminal to_cursor active";
    };

  };

  home.sessionVariables = {
    TERMINAL = "kitty";
    DEFAULT_TERMINAL = "kitty";
  };
}
