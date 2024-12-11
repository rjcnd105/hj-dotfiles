let-env ENV_CONVERSIONS = {
  "PATH": {
    from_string: { |s| $s | split row (char esep) }
    to_string: { |v| $v | str join (char esep) }
  }
}



# zsh에서 환경변수를 가져와서 nushell에 적용
load-env (^$"/etc/profiles/per-user/($env.USER)/bin/zsh" -ic 'env' | lines | split column "=" | reduce -f {} {|it, acc| $acc | upsert $it.column1 $it.column2})

# PATH는 따로 처리가 필요할 수 있음
$env.PATH = ($env.PATH | append [$"/etc/profiles/per-user/($env.USER)/bin"])

$env.IS_LOAD_ENV_NU = "true"
