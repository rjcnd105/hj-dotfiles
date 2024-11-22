{
  programs.zellij = {
    enable = true;
    settings = {
      theme = "catppuccin-mocha"; # 인기있는 테마

      mouse_mode = true;
      default_layout = "compact"; # 기본 레이아웃
      default_shell = "zsh"; # 기본 쉘
      simplified_ui = true; # 단순화된 UI
      scroll_buffer_size = 10000; # 스크롤 버퍼 크기
      copy_command = "pbcopy"; # macOS 클립보드 (Linux면 xclip이나 wl-copy)

      # 자동 시작/종료 관련
        auto_start = true;           # 터미널 시작시 자동 실행
        attach_to_current = true;     # 가능하면 현재 세션에 연결

        # 세션 관리
          session_manager = {
            check_interval_ms = 5000;  # 세션 체크 간격
          };

      # 상태바 설정
      ui = {
        pane_frames = {
          rounded_corners = true;
        };
      };

      # 터미널 설정
      terminal_features = {
        graphics = true;
        desktop_notifications = true;
      };
      normal = {

        # 팬 이동
        "Alt h" = "NewPaneOrTab Left";
        "Alt l" = "NewPaneOrTab Right";
        "Alt j" = "NewPaneOrTab Down";
        "Alt k" = "NewPaneOrTab Up";

        "Alt n" = "NewTab";
        # 닫기
        "Alt w" = "CloseTab";

        # 레이아웃 전환
        "Alt 1" = {
          LaunchOrFocusPlugin = {
            plugin = "default";
          };
        };
        "Alt 2" = {
          LaunchOrFocusPlugin = {
            plugin = "coding";
          };
        };
        # 전체화면 전환
        "Alt f" = "ToggleFocusFullscreen"; # ⌘ + enter
      };

      # 자동 시작 명령어
      on_force_close = "detach";
    };
  };
}
