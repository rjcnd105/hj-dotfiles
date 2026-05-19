if command -v vcs-kind >/dev/null 2>&1; then
  vcs_kind="$(vcs-kind)"
elif command -v jj >/dev/null 2>&1 && jj root >/dev/null 2>&1; then
  vcs_kind="jj"
else
  vcs_kind="git"
fi

case "$vcs_kind" in
  jj | git) export VCS_KIND="$vcs_kind" ;;
  *) export VCS_KIND="git" ;;
esac
