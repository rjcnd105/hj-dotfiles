let zsh = $"/etc/profiles/per-user/($env.USER)/bin/zsh"

def zsh-env-to-nu-table [ env_content: string ] {
    $env_content
    | lines
    | split column "="
    | where column1 not-in ["PWD", "SHLVL", "OLDPWD", "_", "FILE_PWD", "CURRENT_FILE"]
    | reduce -f {} {|it, acc| $acc | upsert $it.column1 $it.column2}
}

# zsh에서 환경변수를 가져와서 nushell에 적용
zsh-env-to-nu-table (^$zsh -c "env") | load-env
zsh-env-to-nu-table (^$zsh -c $"source /etc/profiles/per-user/($env.USER)/etc/profile.d/hm-session-vars.sh && env") | load-env

$env.IS_LOAD_ENV_NU = "true"
