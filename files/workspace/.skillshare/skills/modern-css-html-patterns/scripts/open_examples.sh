#!/usr/bin/env sh
set -eu

script_dir=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
skill_dir=$(CDPATH= cd -- "$script_dir/.." && pwd)
target=${1:-"$skill_dir/examples"}

case "$target" in
  /*) ;;
  *) target="$skill_dir/$target" ;;
esac

open "$target"
