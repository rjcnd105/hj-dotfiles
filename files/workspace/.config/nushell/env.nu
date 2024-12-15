# 환경변수 파일을 로드하는 함수
def load-env-file [
    file: path  # 로드할 환경변수 파일 경로
] {
    if not ($file | path exists) {
        error make {
            msg: $"File not found: ($file)"
        }
    }

    load-env (^zsh -c $"source ($file) && env"
        | lines
        | split column "="
        | where column1 not-in ["PWD", "SHLVL", "OLDPWD", "_"]
        | reduce -f {} {|it, acc| $acc | upsert $it.column1 $it.column2}
    )
}

$env.ZELLIJ_CONFIG_DIR = "$HOME/.config/zellij"

# zsh에서 환경변수를 가져와서 nushell에 적용
load-env (^$"/etc/profiles/per-user/($env.USER)/bin/zsh" -ic 'env'
  | lines
  | split column "="
  | where column1 != "PWD"
  | reduce -f {} {|it, acc| $acc | upsert $it.column1 $it.column2})

load-env-file $"/etc/profiles/per-user/($env.USER)/etc/profile.d/hm-session-vars.sh"

$env.IS_LOAD_ENV_NU = "true"
