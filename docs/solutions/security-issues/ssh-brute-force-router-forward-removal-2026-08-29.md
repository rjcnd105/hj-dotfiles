---
module: homelab
tags: [ssh, cloudflared, cloudflare-access, router, sshd]
problem_type: security-incident
---

# SSH 무차별 대입 — 라우터 포워딩 제거 + Cloudflare Tunnel SSH 전환

## 증상

- sshd 저널에 초당 십수 회의 `Invalid user` / `Failed keyboard-interactive/pam`.
- 14일간 sshd 로그 217만 줄 — 전체 저널(3.9G) 1위, 상시 CPU/디스크 소모.
- 온도 경보 오탐의 배경 소음원이기도 했다.

## 원인

공유기가 공개 인터넷의 비표준 포트를 호스트 22로 포워딩하고 있었고, DDNS
호스트명이 등록되어 있었다. 비표준 포트는 봇넷 스캔 목록에 포함되어 있어
방어 효과가 없었다. `PasswordAuthentication no`여도
`KbdInteractiveAuthentication`이 기본값(yes)이라 PAM 경유 비밀번호 시도가
계속 처리되고 로그를 생성했다.

## 해결

1. 공유기 포트포워딩 규칙 제거(공격 트래픽이 호스트에 도달 자체를 못 함).
   제거 시각과 동시에 공격 로그가 0이 된 것으로 인과 확인.
2. 원격 SSH는 기존 Cloudflare Tunnel에 `ssh://localhost:22` ingress를 추가해
   CF Access(이메일 OTP) 뒤로 이동. 클라이언트는
   `ProxyCommand cloudflared access ssh --hostname %h`.
3. `KbdInteractiveAuthentication = false`로 PAM 비밀번호 경로 폐쇄(심층 방어).
4. LAN 직결(`homelab-lan`)을 폴백 경로로 유지 — 터널/Access 장애 시 락아웃 방지.

## 교훈

- 인바운드 포트 개방 + DDNS는 그 자체로 상시 공격 표면이다. 아웃바운드 전용
  터널(cloudflared)이 이미 있다면 SSH도 그 뒤로 넣는 것이 맞다.
- "비표준 포트로 숨기기"는 스캐너에게 방어가 아니다.
- sshd 로그 폭주는 저널 용량·CPU·모니터링 신뢰도(경보 소음)까지 오염시킨다.
