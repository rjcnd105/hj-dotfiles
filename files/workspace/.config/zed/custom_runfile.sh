#!/bin/bash

# Access the full path using ZED_FILE
full_path="$ZED_FILE"

# Extract filename with extension
filename_ext=$(basename "$full_path")

# Extract filename and extension
filename="${filename_ext%.*}"
extension="${filename_ext##*.}"

if [ "$extension" == "sh" ]; then
    source "$full_path";
elif [ $filename != "flake.nix" -a "$extension" == "nix" ]; then
    nix eval -f "$full_path";
elif [ "$extension" == "py" ]; then
    python3 "$full_path";
elif [ "$extension" == "ts" ]; then
    bunx tsx "$full_path";
else
    echo "run file: Not defined.."
fi
