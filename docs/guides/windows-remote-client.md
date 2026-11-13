# Windows 원격 클라이언트

Windows PC를 Mac `hj`의 herdr 세션에 붙는 클라이언트로 설정하는 런북이다. Windows는 접속하는 쪽만 맡으므로 sshd와 herdr 서버는 Mac에만 둔다. Windows의 에이전트가 PowerShell에서 이 문서를 위에서부터 실행하며, 이 저장소를 checkout할 필요는 없다.

Windows에서 에이전트에게 줄 요청:

```text
https://raw.githubusercontent.com/rjcnd105/hj-dotfiles/main/docs/guides/windows-remote-client.md 를 읽고 그대로 실행해줘.
```

## 실행 규칙

- 단계마다 완료 조건을 확인한 뒤 다음 단계로 간다. 완료 조건을 이미 만족하는 단계는 건너뛴다. 중간에 끊기면 처음부터 다시 실행해도 된다.
- **사용자 차례**는 사용자에게 할 일을 보여주고, 끝냈다는 답을 받은 뒤 이어 간다. 로그인, UAC 승인, Mac 쪽 작업이 여기에 해당한다.
- `~/.ssh/config`는 `Add-Content -Encoding ascii`로 쓴다. PowerShell 5.1의 `>` 리다이렉션은 UTF-16으로 저장하는데, OpenSSH는 UTF-16 파일을 읽지 못한다.
- 대화형 TUI인 `herdr --remote`는 7단계에서 사용자가 Windows Terminal에서 직접 실행한다.

## 1. 전제 확인

```powershell
$PSVersionTable.PSVersion
winget --version
ssh -V
```

완료 조건: 세 명령이 모두 버전을 출력한다.

- `ssh`가 없을 때(**사용자 차례**): 관리자 PowerShell에서 `Add-WindowsCapability -Online -Name OpenSSH.Client~~~~0.0.1.0`을 실행한다.
- `winget`이 없을 때(**사용자 차례**): Microsoft Store에서 App Installer를 설치한다.

## 2. Tailscale

```powershell
winget install --id Tailscale.Tailscale -e --accept-source-agreements --accept-package-agreements
```

**사용자 차례**: 설치 중 UAC 창이 뜨면 승인한다. 설치가 끝나면 작업 표시줄 트레이의 Tailscale 아이콘에서 로그인한다. 계정은 Mac과 같은 Tailscale 계정을 쓴다.

로그인 뒤에는 들어오는 연결을 막고 Mac까지의 경로를 확인한다.

```powershell
$ts = "$env:ProgramFiles\Tailscale\tailscale.exe"
& $ts set --shields-up=true
& $ts status
& $ts ping hj
```

완료 조건: `status` 출력에 `hj`가 있고, `ping hj`가 `pong`을 받는다.

## 3. SSH 키

키가 이미 있으면 그 키를 그대로 쓴다.

```powershell
New-Item -ItemType Directory -Force "$env:USERPROFILE\.ssh" | Out-Null
Test-Path "$env:USERPROFILE\.ssh\id_ed25519"
```

결과가 `False`면 passphrase 없는 키를 만든다. `--%` 뒤의 내용은 PowerShell이 해석하지 않고 그대로 넘기므로, PowerShell 버전과 관계없이 `-N ""`가 빈 문자열로 전달된다. 이 명령은 다른 명령과 섞지 말고 한 줄로 따로 실행한다.

```powershell
ssh-keygen --% -q -t ed25519 -C windows-pc -f "%USERPROFILE%\.ssh\id_ed25519" -N ""
```

완료 조건: `ssh-keygen -y -f "$env:USERPROFILE\.ssh\id_ed25519"`가 아무것도 묻지 않고 공개키 한 줄을 출력한다.

키에 passphrase가 없으므로 ssh-agent는 쓰지 않는다. 기존 키가 passphrase를 묻는 경우는 **사용자 차례**다. 사용자가 관리자 PowerShell에서 `Set-Service ssh-agent -StartupType Automatic`과 `Start-Service ssh-agent`를 실행한 뒤, 일반 PowerShell에서 `ssh-add`를 실행한다.

## 4. Mac에 공개키 등록

**사용자 차례**. 먼저 공개키를 출력해 사용자에게 보여준다.

```powershell
Get-Content "$env:USERPROFILE\.ssh\id_ed25519.pub"
```

Mac의 sshd는 키 인증만 받는다. 허용할 키는 nix-dots의 `systems/default.nix`에 있는 `openssh.authorizedKeys.keys` 목록에 선언한다. 사용자는 Mac에서 이 공개키를 `# Windows PC` 주석과 함께 목록에 추가하고 `just darwin-switch`를 실행한다. Mac의 에이전트에게 공개키를 주면서 "Windows PC 키로 추가하고 switch해줘"라고 맡겨도 된다.

완료 조건: 사용자가 Mac에서 switch를 마쳤다고 답한다.

## 5. SSH 접속

```powershell
$cfg = "$env:USERPROFILE\.ssh\config"
if (-not (Select-String -Quiet -Pattern '^Host mac$' -Path $cfg -ErrorAction SilentlyContinue)) {
  Add-Content -Encoding ascii -Path $cfg -Value "`r`nHost mac`r`n  HostName hj`r`n  User hj`r`n  StrictHostKeyChecking accept-new"
}
ssh -o BatchMode=yes mac "echo ok"
```

`StrictHostKeyChecking accept-new`는 첫 접속 때 Mac의 호스트 키를 자동으로 저장한다. 이 경로는 Tailscale(WireGuard)이 상대 기기를 인증해 주기 때문에 이렇게 설정해도 된다.

완료 조건: 마지막 명령이 `ok`를 출력한다.

## 6. herdr 클라이언트

```powershell
powershell -ExecutionPolicy Bypass -c "irm https://herdr.dev/install.ps1 | iex"
```

보안 소프트웨어가 이 명령을 막으면, Command Prompt에서 `curl.exe -fsSLo install.cmd https://herdr.dev/install.cmd && install.cmd && del install.cmd`를 실행한다.

Windows의 herdr는 `--remote` 클라이언트로만 쓴다. 따라서 서버 설정이나 `herdr machine` 등록은 하지 않는다.

완료 조건: 새 PowerShell 창에서 `herdr --version`이 버전을 출력한다.

## 7. 사용자에게 넘기기

에이전트는 아래 사용법을 사용자에게 전하고 작업을 마친다. 사용자는 Windows Terminal에서 실행한다.

```powershell
herdr --remote mac                    # Mac의 기본 세션
herdr --remote mac --session <이름>   # 이름 있는 세션
```

herdr 클라이언트를 거치지 않는 방법도 있다. `ssh mac`으로 접속한 뒤 Mac에서 `herdr --session <이름>`이나 `herdr session attach <이름>`을 실행하면 같은 세션에 붙는다.

## 문제 해결

- `hj` 이름을 찾지 못하면 `tailscale status`에 나오는 Mac의 Tailscale IP를 `~/.ssh/config`의 `HostName`에 넣는다.
- `Permission denied (publickey)`가 나오면 4단계의 Mac switch가 끝났는지, 그리고 Mac에 등록한 키가 `id_ed25519.pub`의 내용과 같은지 확인한다.
- `tailscale set`이 권한 오류를 내면 관리자 PowerShell에서 같은 명령을 실행한다(**사용자 차례**).
- 한글 IME 후보창이 엉뚱한 위치에 뜨면 `%APPDATA%\herdr\config.toml`의 `[ui]` 섹션에 `host_cursor = "native"`를 넣는다. 이 설정은 커서 깜빡임을 다시 불러올 수 있다.
- `herdr --remote mac`이 붙지 못하면 `ssh mac`으로 접속해 Mac에서 `herdr`를 직접 실행해 세션을 띄운 뒤 다시 시도한다.
