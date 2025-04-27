{
  programs.espanso = {
    enable = true;

    global_vars = {
      global_vars = [
        {
          name = "currentdate";
          type = "date";
          params = {
            format = "%Y.%m.%d";
          };
        }
        {
          name = "currenttime";
          type = "date";
          params = {
            format = "%H:%M:%S";
          };
        }
      ];
    };
  };
}
