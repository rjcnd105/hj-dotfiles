# ipTIME 외부 SSH 접속 설정 가이드

ipTIME 공유기 환경에서 외부 네트워크로부터 homelab에 SSH 접속을 허용하는 설정.

**전제조건:**
- homelab NixOS 설치 완료
- 내부 네트워크에서 SSH 접속 확인 (`ssh hj@<내부IP>`)
- ipTIME 관리 페이지 접속 가능 (기본: `192.168.0.1`)

---

## 1. homelab 내부 IP 고정

DHCP가 IP를 변경하면 포트포워딩이 깨지므로 IP를 고정한다.

ipTIME 관리 페이지:
1. **고급 설정** → **네트워크 관리** → **DHCP 서버 설정** → **수동 IP 할당**
2. homelab의 MAC 주소와 원하는 IP를 등록 (예: `192.168.0.100`)
3. 적용

homelab의 MAC 주소 확인:
```bash
ip link show
# enp* 또는 eth0의 link/ether 뒤에 나오는 값 (예: aa:bb:cc:dd:ee:ff)
```

## 2. 포트포워딩 설정

ipTIME 관리 페이지:
1. **고급 설정** → **NAT/라우터 관리** → **포트포워드 설정**
2. 새 규칙 추가:

| 항목 | 값 |
|------|-----|
| 규칙이름 | homelab-ssh |
| 내부 IP 주소 | 고정한 IP (예: `192.168.0.100`) |
| 프로토콜 | TCP |
| 외부 포트 | 2222 (기본 22 대신 변경 권장) |
| 내부 포트 | 22 |

3. 적용

> 외부 포트를 22가 아닌 2222 등으로 바꾸면 자동 스캔 봇 대부분을 회피할 수 있다.

## 3. 외부 IP 확인

```bash
curl ifconfig.me
```

## 4. 외부 접속 테스트

내부 네트워크가 아닌 곳(모바일 핫스팟 등)에서:
```bash
ssh -p 2222 hj@<외부IP>
```

> 같은 공유기 내부에서 외부 IP로 접속하면 안 되는 경우가 있다 (NAT hairpinning 미지원). 반드시 외부 네트워크에서 테스트한다.

## 5. (권장) DDNS 설정

가정용 인터넷은 외부 IP가 주기적으로 바뀔 수 있다. DDNS를 설정하면 도메인으로 접속 가능.

ipTIME 관리 페이지:
1. **고급 설정** → **특수기능** → **DDNS 설정**
2. 호스트 이름 입력 (예: `myhomelab`)
3. 등록하면 `myhomelab.iptime.org`로 접속 가능:

```bash
ssh -p 2222 hj@myhomelab.iptime.org
```

## 6. SSH 보안 강화

NixOS 설정에서 확인할 항목:

```nix
services.openssh = {
  settings = {
    PasswordAuthentication = false;  # 키 인증만 허용
    PermitRootLogin = "no";          # root 직접 로그인 차단
  };
};
```

추가로 fail2ban을 활성화하면 brute-force 공격을 자동 차단한다:

```nix
services.fail2ban.enable = true;
```

---

## 트러블슈팅

### 외부에서 접속이 안 됨
- 포트포워딩 규칙의 내부 IP가 맞는지 확인
- 외부 네트워크에서 테스트하고 있는지 확인 (같은 공유기 내부에서는 안 될 수 있음)
- `curl ifconfig.me`로 외부 IP가 바뀌지 않았는지 확인
- homelab에서 `systemctl status sshd` 확인

### Connection refused
- homelab에서 sshd가 실행 중인지 확인
- 포트포워딩의 내부 포트가 22인지 확인
- `ss -tlnp | grep 22`로 22번 포트가 리스닝 중인지 확인

### Connection timeout
- 포트포워딩 규칙이 적용되었는지 확인
- ISP가 포트를 차단하고 있을 수 있음 — 다른 외부 포트(예: 443, 8022)로 변경 시도
