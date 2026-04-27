if test -d /opt/homebrew/bin
  # Apple Silicon (M1, M2, etc.)
  eval (/opt/homebrew/bin/brew shellenv)
end

# set mise_exec "/Users/$USER/.local/bin/mise"
# if test -f "$mise_exec"
#   "$mise_exec" shellenv | source
# end
source $HOME/.config/fish/activate.fish
if test -f $HOME/.config/fish/completions/mise.fish
  source $HOME/.config/fish/completions/mise.fish
end

function skills --wraps skills --description "Run skills CLI with repo-local agent mirror limits"
  set -l subcommand $argv[1]

  switch "$subcommand"
    case add a experimental_sync
      if contains -- --agent $argv; or contains -- -a $argv
        command skills $argv
      else
        command skills $argv --agent claude-code codex
      end
      and skills-cleanup
    case update upgrade
      command skills $argv
      and skills-cleanup
    case '*'
      command skills $argv
  end
end


function cleanup_zombies --description "좀비 + 고아 프로세스 정리"
  # 좀비 프로세스 (state=Z) 부모 kill → init이 reap
  set zombie_parents (ps -eo pid,ppid,stat,cmd | awk '$3 ~ /Z/ {print $2}' | sort -u)
  if test -n "$zombie_parents"
    echo "좀비 부모 프로세스 kill: $zombie_parents"
    for ppid in $zombie_parents
      kill -9 $ppid 2>/dev/null
    end
  end

  # 고아 프로세스 (PPID=1, 내 소유, sshd/fish 제외)
  set orphans (ps -eo pid,ppid,user,cmd | awk -v u=(whoami) '$2==1 && $3==u && $4 !~ /fish|sshd|systemd/' | awk '{print $1}')
  if test -n "$orphans"
    echo "고아 프로세스 kill: $orphans"
    for pid in $orphans
      kill -9 $pid 2>/dev/null
    end
  end

  if test -z "$zombie_parents" -a -z "$orphans"
    echo "정리할 프로세스 없음"
  end
end

function kill_port
  if test (count $argv) -ne 1
    echo "Usage: kill_port <port>"
    return 1
  end

  set port $argv[1]
  set pids (lsof -ti:$port)

  if test -z "$pids"
    echo "No process found on port $port"
    return 1
  end

  echo "Killing processes on port $port with PIDs: $pids"
  for pid in $pids
    kill -9 $pid
  end
  echo "Processes on port $port have been killed."
end
