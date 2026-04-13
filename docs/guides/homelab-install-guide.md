# Homelab NixOS 설치 가이드

SER9 Pro HX370에 NixOS를 설치하는 단계별 가이드.

**준비물:**
- SER9 Pro HX370 (Windows 설치 상태)
- NixOS minimal ISO가 구워진 USB
- 유선 랜 케이블 (WiFi 드라이버 호환성 불확실)
- Mac에서 이 repo가 최신 상태로 push되어 있어야 함

---

## Phase 1: BIOS 설정

1. **NixOS minimal USB를 꽂은 상태로** SER9 Pro 전원 켜고 `DEL` 또는 `F2`로 BIOS 진입
2. **Security** 탭 -> **Secure Boot**: `Disabled` (NixOS는 기본적으로 Secure Boot 미지원)
3. UEFI 모드 확인: Boot 또는 Advanced 탭에 `CSM` 항목이 있으면 `Disabled`로 설정. 항목 자체가 없으면 이미 UEFI 전용이므로 넘어간다
4. `F4` 또는 Save & Exit 탭에서 저장 후 재부팅

## Phase 2: USB 부팅

1. 재부팅 시 `F7` 또는 `F11`을 눌러 one-time boot menu 진입
2. 목록에서 USB 디바이스 선택 (UEFI: USB명 으로 표시됨)
3. NixOS 부팅 메뉴가 나오면 기본 항목 선택
4. 쉘이 뜨면 성공

> Boot Option #1을 영구적으로 바꿀 필요 없다. 설치 후에는 NVMe에서 부팅해야 하므로 one-time boot menu가 더 간편하다.

## Phase 3: root 전환 + 네트워크 확인

NixOS minimal ISO는 일반 사용자(`nixos`)로 로그인된다. 이후 모든 작업에 root 권한이 필요하므로 먼저 전환:

```bash
sudo -i
```

네트워크 확인:
```bash
# 유선 연결 확인
ip a
# eth0 또는 enp*에 IP가 할당되어 있는지 확인

# 인터넷 연결 테스트
ping -c 3 nixos.org
```

만약 IP가 없으면:
```bash
dhcpcd
```

WiFi를 써야 하는 경우 (유선이 안 되면):
```bash
nmcli device wifi list
nmcli device wifi connect "SSID이름" password "비밀번호"
```

> 네트워크가 안 되면 이후 단계 진행 불가. 반드시 해결하고 넘어갈 것.

## Phase 4: 디스크 확인

```bash
lsblk
```

TYPE이 `disk`인 항목 중 용량으로 NVMe SSD를 식별한다:
- `nvme0n1` (931.5G) -- 내장 NVMe SSD
- `sda` (30G 등) -- USB 부팅 디스크

이하 `/dev/nvme0n1`을 사용한다. 디바이스 이름이 다르면 적절히 대체.

> **주의**: 이 과정에서 NVMe 디스크의 모든 데이터(Windows 포함)가 삭제된다.

## Phase 5: 파티셔닝

```bash
# 기존 파티션 테이블 삭제하고 GPT로 새로 만듦
parted /dev/nvme0n1 -- mklabel gpt

# EFI 파티션 (512MB) -- 부트로더가 들어갈 공간
parted /dev/nvme0n1 -- mkpart ESP fat32 1MB 512MB
parted /dev/nvme0n1 -- set 1 esp on

# 나머지 전체를 하나의 파티션으로
parted /dev/nvme0n1 -- mkpart primary 512MB 100%
```

> `you may need to update /etc/fstab` 경고가 나오면 무시. 라이브 환경에서는 해당 없음.

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
btrfs subvolume create /mnt/@nix     # Nix store (/nix) -- 재빌드 가능, 백업 불필요
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

이 명령은 `/mnt/etc/nixos/`에 `hardware-configuration.nix`와 `configuration.nix`를 생성한다.
따로 기록해둘 필요 없이 다음 단계에서 바로 사용한다.

> 파일이 길어서 터미널에 다 안 보여도 괜찮다. 내용을 확인할 필요 없이 다음 단계로 넘어간다.

## Phase 10: flake repo 클론 + hardware-configuration.nix 적용

`nixos-generate-config`가 `/mnt/etc/nixos/`를 이미 만들었으므로, 백업 후 교체한다:

```bash
# hardware-configuration.nix 백업
mv /mnt/etc/nixos/hardware-configuration.nix /tmp/hw-config.nix

# 기존 폴더 삭제 후 repo 클론
rm -rf /mnt/etc/nixos
nix-shell -p git
git clone https://github.com/rjcnd105/hj-dotfiles /mnt/etc/nixos

# 백업해둔 hardware-configuration.nix를 repo 위치로 복사
cp /tmp/hw-config.nix /mnt/etc/nixos/systems/homelab/hardware-configuration.nix
```

> `hardware-configuration.nix`는 하드웨어 자동감지 결과(파일시스템 UUID, 커널 모듈 등)로 민감 정보가 없다. 공개 repo에 커밋해도 무방.

## Phase 11: 설치

`ENABLE_SECRETS=0`으로 secrets 없이 설치한다. age 키가 아직 없으므로 secrets는 Phase 17 이후에 설정한다.

```bash
# NixOS 설치 (secrets 제외)
ENABLE_SECRETS=0 nixos-install --flake /mnt/etc/nixos#homelab_hj
```

설치 중 root 비밀번호를 묻는다. 설정한다.

> 설치가 실패하면 에러 메시지를 잘 읽는다. 대부분 hardware-configuration.nix 누락이거나 네트워크 문제.

## Phase 13: 재부팅

```bash
# USB 뽑기
reboot
```

## Phase 14: 첫 로그인

부팅 후 콘솔에서:
```bash
# root로 로그인 (Phase 12에서 설정한 비밀번호)
# 사용자 비밀번호 설정
passwd hj
```

## Phase 15: SSH 접속 설정

homelab 콘솔에서 IP 확인:
```bash
ip a
# eth0 또는 enp*의 inet 주소 확인
```

Mac에서 SSH 공개키 복사 + 접속:
```bash
# 공개키를 homelab에 복사 (비밀번호 입력)
ssh-copy-id hj@<homelab-ip>

# 이후 키 인증으로 접속
ssh hj@<homelab-ip>
```

접속이 되면 성공.

> 선언적 관리를 위해 나중에 `openssh.authorizedKeys.keys`에도 공개키를 추가하고 rebuild하는 것을 권장한다.

## Phase 16: 서비스 확인

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

## Phase 17: age key 생성 (Secrets 설정)

homelab에서:
```bash
# SSH 키가 없으면 생성
ssh-keygen -t ed25519 -C "hj@homelab"

# age public key 추출
nix-shell -p ssh-to-age --run 'cat ~/.ssh/id_ed25519.pub | ssh-to-age'
# 출력: age1... <- 이 값을 복사
```

## Phase 18: Mac에서 secrets 설정

Mac에서:
```bash
cd ~/dot/nix-dots
```

### 1. `.sops.yaml`에 homelab age key 추가

```yaml
keys:
  - &hj_age age14c6z2hf8qr9lumph8smjh7yny25nd7v4xy9guc8n5r2pfrmhjfasrjmhz5
  - &homelab_age age1여기에_Phase17의_값_붙여넣기
```

creation_rules에서 homelab 섹션 주석 해제:
```yaml
  - path_regex: secrets/homelab/[^/]+\.(yaml|json|env|ini)$
    key_groups:
      - age:
          - *hj_age
          - *homelab_age
```

### 2. workspace secrets를 homelab용으로 복사 + 재암호화

```bash
cp secrets/workspace/secrets.yaml secrets/homelab/secrets.yaml
cp secrets/workspace/last30days.enc.yaml secrets/homelab/last30days.enc.yaml

sops updatekeys secrets/homelab/secrets.yaml
sops updatekeys secrets/homelab/last30days.enc.yaml
```

## Phase 19: 커밋 + push

Mac에서:
```bash
cd ~/dot/nix-dots

git add systems/homelab/hardware-configuration.nix \
      .sops.yaml \
      secrets/homelab/
git commit -m "chore: homelab secrets 설정 추가"
git push
```

push 후 comin이 homelab에서 자동으로 변경을 감지하고 secrets 포함 rebuild를 수행한다.
(`ENABLE_SECRETS` 환경 변수를 넘기지 않으면 기본적으로 secrets 포함)

## Phase 20: comin 동작 확인

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
- BIOS에서 NVMe SSD가 Boot Option에 있는지 확인

### 네트워크 안 됨
- 유선 케이블 확인
- `ip link` 로 인터페이스 확인
- `dhcpcd 인터페이스이름` 으로 수동 DHCP

### nixos-install 실패
- `hardware-configuration.nix`가 올바른지 확인
- 네트워크 연결 확인 (패키지 다운로드 필요)
- sops 관련 에러: `ENABLE_SECRETS=0`을 붙여서 실행했는지 확인

### SSH 접속 안 됨
- homelab에서 `systemctl status sshd` 확인
- `ip a`로 IP 확인
- Mac에서 `ssh-copy-id`를 했는지 확인
- 방화벽: `sudo iptables -L` 로 22번 포트 확인

### comin이 변경을 감지 안 함
- `systemctl status comin` 으로 서비스 상태 확인
- `journalctl -u comin` 으로 에러 확인
- GitHub repo URL이 맞는지 확인 (public repo여야 함)
