
def local_psql [db: string] {
    usql $"postgres://($env.PGHOST):($env.PGPORT)/($db)"
}

def start_zellij [] {
  if 'ZELLIJ' not-in ($env | columns) {
    if 'ZELLIJ_AUTO_ATTACH' in ($env | columns) and $env.ZELLIJ_AUTO_ATTACH == 'true' {
      zellij attach -c
    } else {
      zellij
    }

    if 'ZELLIJ_AUTO_EXIT' in ($env | columns) and $env.ZELLIJ_AUTO_EXIT == 'true' {
      exit
    }
  }
}


# rio에서만 zellij 실행
if $env.TERM_PROGRAM == "rio" {
   start_zellij
}


$env.IS_LOGIN_NU_LOADED = "true"
