#!/bin/bash
full_path="$ZED_FILE"
filename_ext=$(basename "$full_path")
extension="${filename_ext##*.}"

if [ "$extension" = "sh" ]; then
    source "$full_path"
elif [ "$filename_ext" != "flake.nix" ] && [ "$extension" = "nix" ]; then
    nix eval -f "$full_path"
elif [ "$extension" = "py" ]; then
    python3 "$full_path"
elif [ "$extension" = "ts" ]; then
    bunx tsx "$full_path"
else
    echo "run file: Not defined.."
fi
