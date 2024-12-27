#!/bin/bash
set -euo pipefail

# env.nix 파일 생성
cat > env.nix << EOF
{
  PWD = "$(pwd)";
}
EOF
