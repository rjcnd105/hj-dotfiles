
complete -c jj -n "__fish_jj_needs_command" -f -a fetch -d 'Fetch from all remotes'
complete -c jj -n "__fish_jj_needs_command" -f -a publish -d 'Push bookmarks with --allow-new'
complete -c jj -n "__fish_jj_needs_command" -f -a consume -d 'Move content from <rev> into @'
complete -c jj -n "__fish_jj_needs_command" -f -a eject -d 'Move content from @ into <rev>'
complete -c jj -n "__fish_jj_needs_command" -f -a bmove -d 'Move bookmark to @'
complete -c jj -n "__fish_jj_needs_command" -f -a "bmove-" -d 'Move bookmark to @-'
complete -c jj -n "__fish_jj_needs_command" -f -a "done" -d 'Commit and move bookmark to @-'

# --- 공통 추출 함수 ---
function __fish_jj_get_bookmarks
    jj bookmark list --format 'self.name() + "\n"' 2>/dev/null | string trim
end

function __fish_jj_get_remotes
    jj git remote list 2>/dev/null | string trim
end

# [fetch] 리모트 이름 추천
complete -c jj -n "__fish_jj_using_subcommand fetch" -a "(__fish_jj_get_remotes)" -d 'Remote'

# [publish] 북마크 이름 추천
complete -c jj -n "__fish_jj_using_subcommand publish" -a "(__fish_jj_get_bookmarks)" -d 'Bookmark'

# [consume] 첫 번째 인자는 리비전(북마크), 그 뒤는 파일
complete -c jj -n "__fish_jj_using_subcommand consume" -n "__fish_is_nth_token 2" -a "(__fish_jj_get_bookmarks)" -d 'Revision'
complete -c jj -n "__fish_jj_using_subcommand consume" -n "__fish_is_nth_token 3" -F # 3번째 인자부터는 파일(디렉토리 포함)

# [eject] 첫 번째 인자는 리비전(북마크), 그 뒤는 파일
# -i 옵션 지원 추가
complete -c jj -n "__fish_jj_using_subcommand eject" -s i -l interactive -d 'Interactively choose parts'
complete -c jj -n "__fish_jj_using_subcommand eject" -n "__fish_is_nth_token 2" -a "(__fish_jj_get_bookmarks)" -d 'Revision'
complete -c jj -n "__fish_jj_using_subcommand eject" -n "__fish_is_nth_token 3" -F

# [bmove, bmove-] 북마크 이름 추천
complete -c jj -n "__fish_jj_using_subcommand bmove bmove-" -a "(__fish_jj_get_bookmarks)" -d 'Bookmark'

# [done] 북마크 이름 추천
complete -c jj -n "__fish_jj_using_subcommand done" -a "(__fish_jj_get_bookmarks)" -d 'Bookmark'
