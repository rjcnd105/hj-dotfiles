---
title: Claude Code Remote Control — NixOS systemd user service 상주 배포
date: 2026-04-17
category: developer-experience
module: homelab
problem_type: developer_experience
component: tooling
severity: low
applies_when:
  - 홈랩/서버에서 claude.ai 모바일·웹 앱으로 세션에 접속하고 싶을 때
  - Claude Code 세션을 재부팅 후에도 자동으로 상주시키고 싶을 때
  - NixOS + home-manager 환경에서 선언형으로 데몬을 관리하고 싶을 때
tags: [claude-code, nixos, home-manager, systemd, remote-control, homelab]
---

# Claude Code Remote Control — NixOS systemd user service 상주 배포

## Context

홈랩 NixOS 서버에 Claude Code 원격 세션을 항상 띄워두고, 폰(claude.ai 앱)에서 언제든 접속·재개하고 싶은 상황. `ssh + tmux`는 앱 네이티브 경험이 아니고, Cloudflare Tunnel로 웹 터미널을 노출하는 것도 과함.

Claude Code v2.1.51+부터 제공되는 **Remote Control** 기능이 정확한 해법. 로컬에서 `claude remote-control`을 실행하면 Anthropic API를 경유하는 아웃바운드 HTTPS로 claude.ai/code와 모바일 앱에 세션이 노출된다. 방화벽 개방, Cloudflare Tunnel 모두 불필요.

남는 문제는 "재부팅 후에도, 로그인 없이도 자동 상주"를 선언형으로 어떻게 보장하느냐.

## Guidance

**home-manager `systemd.user.services`로 데몬 정의 + NixOS `users.users.<name>.linger = true`로 부팅 상주** 조합이 가장 단순하고 깔끔하다.

### 1. home-manager 모듈

```nix
# homes/homelab/claude-remote-control.nix
{ pkgs, ... }:
{
  systemd.user.services.claude-remote-control = {
    Unit = {
      Description = "Claude Code Remote Control daemon";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "simple";
      WorkingDirectory = "/etc/nixos";  # 모바일 앱 새 세션이 열릴 기본 경로
      # `echo y | …` — 첫 실행 시 "Enable Remote Control? (y/n)" 동의 prompt 자동 통과
      # (systemd stdin 부재 환경에서 응답 못 하면 CLI가 exit 0으로 종료)
      ExecStart = "${pkgs.bash}/bin/bash -c 'echo y | exec ${pkgs.claude-code}/bin/claude remote-control --capacity 4'";
      Restart = "always";   # 정상 종료 시에도 재기동 — "항상 1개 세션" 보장
      RestartSec = 30;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
```

해당 파일을 `homes/homelab/default.nix`의 `imports`에 추가한다.

### 2. NixOS linger 활성화

```nix
# systems/x86_64-linux/default.nix
users.users.${myOptions.userName} = {
  isNormalUser = true;
  # ...
  linger = true;  # 로그인 없이도 user systemd 세션 유지
};
```

`users.users.<name>.linger` 옵션은 nixpkgs 25.11+에서 지원(nullOr bool). `users.manageLingering = true`(기본값)이면 선언형으로 `loginctl enable-linger`가 자동 실행된다.

### 3. 최초 로그인

`claude` CLI는 credential을 `~/.claude/`에 저장한다. 서비스가 돌기 전에 해당 유저로 한 번 대화식 `claude` 실행 후 Pro/Max 로그인을 완료해야 한다. 로그인 상태가 없으면 데몬은 기동돼도 세션이 앱에 나타나지 않는다.

### 4. 첫 실행 동의 prompt — wrapper 필수 (Claude Code v2.1.92+)

`claude remote-control`은 **최초 기동 시 stdin으로 "Enable Remote Control? (y/n)" 동의 prompt를 띄운다.** systemd service는 기본적으로 stdin이 없으므로 응답을 받지 못하고 CLI가 exit 0으로 즉시 종료된다. 로그만 보면 `Started ...` → 몇백 ms 후 종료 → `Active: inactive (dead)` 로 남아 앱 세션 목록에도 나타나지 않는다.

해결은 ExecStart에 bash wrapper를 한 겹 씌워 `echo y`를 파이프로 주입:

```nix
ExecStart = "${pkgs.bash}/bin/bash -c 'echo y | exec ${pkgs.claude-code}/bin/claude remote-control --capacity 4'";
```

- `echo y` 한 줄만 주입 — 이후 stdin은 EOF, claude는 비대화 모드로 계속 동작
- `exec`로 bash를 claude 프로세스로 대체해 systemd가 PID를 정확히 추적
- 이미 동의된 호스트에선 prompt가 안 뜨고 `y`는 무시되므로 idempotent

함께 `Restart = "always"` 로 바꾸면 예기치 않은 정상 종료(exit 0)에도 재기동되어 "항상 1개 세션 상주" 불변이 보장된다. `on-failure`는 exit 0이면 재기동하지 않는 점을 명심.

## Why This Matters

- **앱 네이티브 접근**: SSH client 없이 claude.ai 앱만으로 홈랩 개발. 통근·외출 중 알림으로 이어받기 자연스러움.
- **선언형 관리**: systemd user service + linger 조합은 NixOS 전체 선언형 스타일과 일치. 수동 `loginctl` 명령 불필요.
- **방화벽 무변경**: Remote Control은 아웃바운드 HTTPS만 사용. 포트 개방, Cloudflare Tunnel 설정 모두 불필요 → 공격 표면 증가 없음.
- **comin과 궁합**: GitOps로 `nixos-rebuild switch`가 자동 실행되면 서비스 정의 변경도 자동 반영.

## When to Apply

- Homelab/VPS NixOS 서버에 Claude Code 상주가 필요할 때
- 모바일·멀티 디바이스 접근이 우선순위일 때
- Cloudflare Tunnel 등 외부 노출 인프라가 부담스러울 때

## Examples

### 커밋 단위 분리

작업 중 `homes/homelab/claude-remote-control.nix` 파일 생성 + `default.nix` import는 이전 세션 auto-snapshot으로 이미 main에 포함된 상태였음. 남은 것은 linger 한 줄. `jj split`으로 설정 캐시(`.claude/settings.local.json`)와 분리해 단독 커밋.

```bash
# 비대화식 환경에서 jj split 실행 (helix 같은 TUI 에디터 회피)
JJ_EDITOR=true jj split -r @ systems/x86_64-linux/default.nix

# 설명 부여 후 main 이동
jj describe <linger-change-id> -m 'feat(homelab): linger 활성화 — ...'
jj bookmark set main -r <linger-change-id>
jj git push --bookmark main
```

### 확인

```bash
ssh homelab 'systemctl --user status claude-remote-control'
# 실행 중이면 claude.ai 앱 세션 목록에 홈랩 노출
```

### capacity 숫자

혼자 쓰는 경우 `--capacity 4` 충분. 모바일·데스크탑·노트북 동시 접속 + 백업 세션 여유 1. 팀 공유 시 더 올릴 것.

## Related

- 솔루션: `docs/solutions/runtime-errors/nixos-kswapd-livelock-zero-swap-2026-04-16.md` (같은 홈랩 안정성 맥락)
- 공식 문서: https://code.claude.com/docs/en/remote-control.md
- nixpkgs 소스: `nixos/modules/config/users-groups.nix`의 `linger` 옵션 정의
