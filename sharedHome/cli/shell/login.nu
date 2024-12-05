def --env load_zsh_env [] {
    let zsh_env = (^/bin/zsh -ic 'env' | lines | split column "=" --collapse-empty)
    let restricted_vars = ["PWD" "OLDPWD" "LAST_EXIT_CODE" "CMD_DURATION_MS" "SHELL"]

    for item in $zsh_env {
        if ($item.column1 not-in $restricted_vars) {
            load-env { $item.column1: $item.column2 }
        }
    }
}

load_zsh_env
echo "get env from zsh"
