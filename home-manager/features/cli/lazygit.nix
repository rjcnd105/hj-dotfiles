{
  programs.lazygit = {
    settings = {
      gui = {
        language = "ko";
        showIcons = true;
      };
      os = {
        editCommand = "zed";
        editCommandTemplate = "zed {{filename}}";
      };
      git = {
        # 커밋 메시지 템플릿 사용
        commitTemplate = "/.git-template/commit-template";
        # 브랜치 정렬
        branchSortOrder = [ "date" ];
        paging = {
          colorArg = "always";
          pager = "pager: delta --dark --paging=never";
        };
      };
      # 추가 키바인딩
      keybinding = {
        branches = {
          createPullRequest = "p";
          checkoutBranchByName = "c";
        };
        commits = {
          amendToCommit = "a";
        };
      };
      # 커스텀 명령어
      customCommands = [
        {
          key = "W";
          command = "git rebase -i HEAD~5";
          description = "rebase last 5 commits";
          context = "global";
        }
        {
          key = "u";
          context = "files";
          description = "stash include untracked";
          command = ''git stash save --include-untracked "{{index .PromptResponses 0}}"'';
          prompts = [
            {
              type = "input";
              title = "Stash Message";
              initialValue = "WIP";
            }
          ];
        }
      ];
    };
  };
  programs.zsh.shellAliases = {
    lzg = "lazygit";
  };
}
