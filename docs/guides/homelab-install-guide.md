# Homelab NixOS 설치 가이드

SER9 Pro HX370에 NixOS를 설치하는 단계별 가이드.

**준비물:**
- SER9 Pro HX370 (Windows 설치 상태)
- NixOS minimal ISO가 구워진 USB
- 유선 랜 케이블 (WiFi 드라이버 호환성 불확실)
- Mac에서 이 repo가 최신 상태로 push되어 있어야 함

---

## Phase 1: BIOS 설정

1. SER9 Pro 전원 켜고 `DEL` 또는 `F2`로 BIOS 진입
2. 확인/변경할 항목:
   - **Secure Boot**: `Disabled` (NixOS는 기본적으로 Secure Boot 미지원)
   - **Boot Order**: USB를 1순위로
   - **UEFI Mode**: 활성화 확인 (Legacy/CSM 아닌 UEFI)
3. 저장 후 재부팅

## Phase 2: USB 부팅

1. NixOS minimal USB를 꽂고 부팅
2. 부팅 메뉴가 나오면 기본 항목 선택
3. root 쉘이 뜨면 성공

## Phase 3: 네트워크 확인

```bash
# 유선 연결 확인
ip a
# eth0 또는 enp*에 IP가 할당되어 있는지 확인

# 인터넷 연결 테스트
ping -c 3 nixos.org
```

만약 IP가 없으면:
```bash
# DHCP 수동 요청
dhcpcd
```

WiFi를 써야 하는 경우 (유선이 안 되면):
```bash
# WiFi 네트워크 목록 확인
nmcli device wifi list

# WiFi 연결
nmcli device wifi connect "SSID이름" password "비밀번호"
```

> 네트워크가 안 되면 이후 단계 진행 불가. 반드시 해결하고 넘어갈 것.

## Phase 4: 디스크 확인

```bash
lsblk
```

출력에서 NVMe SSD를 찾는다. 보통 `/dev/nvme0n1`.
용량을 확인해서 맞는 디스크인지 확인한다.

> **주의**: 이 과정에서 디스크의 모든 데이터(Windows 포함)가 삭제된다.

## Phase 5: 파티셔닝

```bash
# 기존 파티션 테이블 삭제하고 GPT로 새로 만듦
parted /dev/nvme0n1 -- mklabel gpt

# EFI 파티션 (512MB) — 부트로더가 들어갈 공간
parted /dev/nvme0n1 -- mkpart ESP fat32 1MB 512MB
parted /dev/nvme0n1 -- set 1 esp on

# 나머지 전체를 하나의 파티션으로
parted /dev/nvme0n1 -- mkpart primary 512MB 100%
```

결과 확인:
```bash
lsblk /dev/nvme0n1
# nvme0n1p1  512M  (EFI)
# nvme0n1p2  나머지 (btrfs가 될 파티션)
```

## Phase 6: 포맷

```bash
# EFI 파티션을 FAT32로 포맷
mkfs.fat -F 32 -n BOOT /dev/nvme0n1p1

# 메인 파티션을 btrfs로 포맷
mkfs.btrfs -L nixos /dev/nvme0n1p2
```

## Phase 7: btrfs 서브볼륨 생성

```bash
# 임시로 마운트
mount /dev/nvme0n1p2 /mnt

# 서브볼륨 생성
btrfs subvolume create /mnt/@        # 루트 (/)
btrfs subvolume create /mnt/@home    # 사용자 데이터 (/home)
btrfs subvolume create /mnt/@nix     # Nix store (/nix) — 재빌드 가능, 백업 불필요
btrfs subvolume create /mnt/@log     # 로그 (/var/log)

# 임시 마운트 해제
umount /mnt
```

## Phase 8: 서브볼륨 마운트

```bash
# 루트 서브볼륨 마운트
mount -o subvol=@,compress=zstd,noatime /dev/nvme0n1p2 /mnt

# 하위 디렉토리 생성
mkdir -p /mnt/{home,nix,var/log,boot}

# 나머지 서브볼륨 마운트
mount -o subvol=@home,compress=zstd,noatime /dev/nvme0n1p2 /mnt/home
mount -o subvol=@nix,compress=zstd,noatime  /dev/nvme0n1p2 /mnt/nix
mount -o subvol=@log,compress=zstd,noatime  /dev/nvme0n1p2 /mnt/var/log

# EFI 파티션 마운트
mount /dev/nvme0n1p1 /mnt/boot
```

마운트 확인:
```bash
mount | grep /mnt
# /mnt, /mnt/home, /mnt/nix, /mnt/var/log, /mnt/boot 5개가 보여야 함
```

## Phase 9: hardware-configuration.nix 생성

```bash
nixos-generate-config --root /mnt
```

생성된 파일 확인:
```bash
cat /mnt/etc/nixos/hardware-configuration.nix
```

이 파일의 내용을 기록해둔다 (사진 찍거나, USB에 복사).

## Phase 10: flake repo 클론

```bash
# git 설치 (minimal ISO에 없을 수 있음)
nix-shell -p git

# repo 클론
git clone https://github.com/rjcnd105/hj-dotfiles /mnt/etc/nixos
```

## Phase 11: hardware-configuration.nix 교체

Phase 9에서 생성된 내용으로 placeholder 파일을 교체한다:

```bash
# Phase 9에서 생성된 파일로 교체
cp /mnt/etc/nixos/hardware-configuration.nix.bak /mnt/etc/nixos/hardware-configuration.nix 2>/dev/null

# 또는 직접 편집 (nano 사용)
nano /mnt/etc/nixos/systems/homelab/hardware-configuration.nix
```

> `nixos-generate-config`가 생성한 `/mnt/etc/nixos/hardware-configuration.nix`의 **내용 전체**를
> repo의 `systems/homelab/hardware-configuration.nix`에 붙여넣는다.

간편한 방법:
```bash
cp /mnt/etc/nixos/hardware-configuration.nix /mnt/etc/nixos/systems/homelab/hardware-configuration.nix
```

> 단, `nixos-generate-config`가 `/mnt/etc/nixos/`에 생성한 `configuration.nix`와 `hardware-configuration.nix`는
> flake 기반 설치에서는 직접 사용하지 않는다. repo의 flake가 대신한다.

## Phase 12: SSH 공개키 추가

Mac에서 SSH 공개키를 가져와야 한다. 미리 USB에 복사해두거나 기억해둔다.

```bash
# Mac에서 공개키 확인 (설치 전에 메모)
# cat ~/.ssh/id_ed25519.pub

# 공개키를 NixOS 설정에 추가
nano /mnt/etc/nixos/systems/x86_64-linux/default.nix
```

`openssh.authorizedKeys.keys` 배열에 공개키를 추가한다:
```nix
openssh.authorizedKeys.keys = [
  "ssh-ed25519 AAAA... hj@workspace"
];
```

## Phase 13: 설치

```bash
# env.nix 생성 (createEnv.sh 실행)
cd /mnt/etc/nixos
bash createEnv.sh

# NixOS 설치
nixos-install --flake /mnt/etc/nixos#homelab_hj --impure
```

설치 중 root 비밀번호를 묻는다. 설정한다.

> 설치가 실패하면 에러 메시지를 잘 읽는다. 대부분 hardware-configuration.nix 누락이거나 네트워크 문제.

## Phase 14: 재부팅

```bash
# USB 뽑기
reboot
```

## Phase 15: 첫 로그인

부팅 후 콘솔에서:
```bash
# root로 로그인 (Phase 13에서 설정한 비밀번호)
# 사용자 비밀번호 설정
passwd hj
```

## Phase 16: SSH 접속 확인

Mac에서:
```bash
# homelab의 IP 확인 (공유기 관리 페이지 또는 homelab 콘솔에서 ip a)
ssh hj@<homelab-ip>
```

접속이 되면 성공.

## Phase 17: 서비스 확인

```bash
# SSH
systemctl status sshd

# Docker
systemctl status docker
docker run hello-world

# llama.cpp
systemctl status llama-cpp

# comin (GitOps)
systemctl status comin
journalctl -u comin -f    # 로그 실시간 확인
```

## Phase 18: age key 생성 (Secrets 설정)

homelab에서:
```bash
# SSH 키가 없으면 생성
ssh-keygen -t ed25519 -C "hj@homelab"

# age public key 생성
nix-shell -p ssh-to-age --run 'cat ~/.ssh/id_ed25519.pub | ssh-to-age'
# 출력: age1... ← 이 값을 복사
```

## Phase 19: Mac에서 secrets 설정

Mac에서:
```bash
cd ~/dot/nix-dots

# .sops.yaml에 homelab age key 추가
# &homelab_age 주석을 해제하고 Phase 18의 값으로 교체
```

`.sops.yaml`에서:
```yaml
keys:
  - &hj_age age14c6z2hf8qr9lumph8smjh7yny25nd7v4xy9guc8n5r2pfrmhjfasrjmhz5
  - &homelab_age age1여기에_Phase18의_값_붙여넣기
```

creation_rules에서 homelab 섹션 주석 해제:
```yaml
  - path_regex: secrets/homelab/[^/]+\.(yaml|json|env|ini)$
    key_groups:
      - age:
          - *hj_age
          - *homelab_age
```

secrets 파일 생성:
```bash
# workspace secrets를 복사하여 homelab용으로 생성
cp secrets/workspace/secrets.yaml secrets/homelab/secrets.yaml
sops updatekeys secrets/homelab/secrets.yaml
```

## Phase 20: hardware-configuration.nix 커밋 + push

Mac에서:
```bash
cd ~/dot/nix-dots

# homelab에서 가져온 hardware-configuration.nix를 커밋
# (Phase 11에서 교체한 내용을 Mac의 repo에도 반영)
git add systems/homelab/hardware-configuration.nix .sops.yaml secrets/homelab/
git commit -m "chore: homelab hardware-configuration 및 secrets 설정 추가"
git push
```

push 후 comin이 homelab에서 자동으로 변경을 감지하고 적용한다.

## Phase 21: comin 동작 확인

homelab에서:
```bash
# comin이 새 커밋을 감지했는지 확인
journalctl -u comin --since "5 minutes ago"
```

---

## 트러블슈팅

### 부팅이 안 됨
- BIOS에서 Secure Boot이 꺼져 있는지 확인
- UEFI 모드인지 확인
- Boot Order에서 NVMe SSD가 1순위인지 확인

### 네트워크 안 됨
- 유선 케이블 확인
- `ip link` 로 인터페이스 확인
- `dhcpcd 인터페이스이름` 으로 수동 DHCP

### nixos-install 실패
- `hardware-configuration.nix`가 올바른지 확인
- `env.nix`가 생성되었는지 확인 (`cat /mnt/etc/nixos/env.nix`)
- 네트워크 연결 확인 (패키지 다운로드 필요)

### SSH 접속 안 됨
- homelab에서 `systemctl status sshd` 확인
- `ip a`로 IP 확인
- `openssh.authorizedKeys.keys`에 공개키가 들어갔는지 확인
- 방화벽: `sudo iptables -L` 로 22번 포트 확인

### comin이 변경을 감지 안 함
- `systemctl status comin` 으로 서비스 상태 확인
- `journalctl -u comin` 으로 에러 확인
- GitHub repo URL이 맞는지 확인 (public repo여야 함)
