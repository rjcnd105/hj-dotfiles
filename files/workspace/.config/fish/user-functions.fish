if test -d /opt/homebrew/bin
  # Apple Silicon (M1, M2, etc.)
  eval (/opt/homebrew/bin/brew shellenv)
end

# set mise_exec "/Users/$USER/.local/bin/mise"
# if test -f "$mise_exec"
#   "$mise_exec" shellenv | source
# end
source $HOME/.config/fish/activate.fish
source $HOME/.config/fish/completions/mise.fish



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
