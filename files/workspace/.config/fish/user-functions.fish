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
