# Fish completions for sops (dynamically generated via --generate-bash-completion)

function __sops_completions
    set -l tokens (commandline -opc)
    set -l current (commandline -ct)

    # Build the completion command
    set -l cmd $tokens
    if string match -q -- '-*' $current
        set -a cmd $current
    end
    set -a cmd --generate-bash-completion

    # Run and output results
    command $cmd 2>/dev/null
end

complete -c sops -f -a '(__sops_completions)'
