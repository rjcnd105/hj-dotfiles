

# 기본 변수 설정
gh_org := "your-organization"
default_env := "development"
default := "Hello, World!"

default:
    @just --list

@dev-up:
    #!/usr/bin/env sh
    set -euxo pipefail
    pwd
    devenv up
# reload:
#     #!/usr/bin/env sh
#     @nix-direnv-reload


# clean:
#     #!/usr/bin/env bash
#     rm -f .env .env.* !.env.template
#     echo "🧹 환경 파일 정리 완료"

# # Comment
# echo msg=default:
#     @echo {{msg}}
