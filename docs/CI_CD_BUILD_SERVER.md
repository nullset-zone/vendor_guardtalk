# GuardTalkOS CI/CD Build Server Specification & DevOps Runbook

> **Target Hardware:** Dell PowerEdge Server — **192 CPU Cores / 512 GB ECC RAM / Enterprise NVMe**  
> **Workload:** Full-fleet AOSP / GrapheneOS / GuardTalkOS `*-cur-user` builds (14 Pixel targets), `adevtool` vendor generation, AVB/APK release signing, QA verification suites, and WebInstaller 14-channel packing.

---

## 1. Dell PowerEdge Hardware Specification

### Recommended Chassis & Compute

| Component | Recommended Specification | Notes |
| :--- | :--- | :--- |
| **Chassis** | **Dell PowerEdge R7625** (2U) or **R6625** (1U) | R7625 (2U) preferred for thermals under sustained 100% all-core Soong/Ninja/LTO builds and up to 24× NVMe bays. |
| **CPUs** | **2× AMD EPYC 9654** (Genoa) or **2× AMD EPYC 9655** (Turin) — 96C/192T each (**192 physical cores / 384 threads**) | Best performance-per-watt for parallel C++/Rust/Java compilation (`clang`, `rustc`, `javac`, `lld` ThinLTO). |
| **Memory** | **512 GB DDR5 ECC RDIMM** (4800–6000 MT/s) | Populate balanced across channels (e.g., **16× 32 GB** RDIMMs across both sockets; or 24× 32 GB = 768 GB if budget allows full 12-channel-per-socket population). |
| **OS Boot Storage** | **2× 480 GB or 960 GB Dell BOSS-N1** (M.2 NVMe, hardware RAID-1) | Isolates OS, CI runner, and logs from heavy build scratch I/O. |
| **Build Scratch NVMe** | **4× 3.84 TB Enterprise U.2 / E3.S NVMe** (PCIe Gen4/Gen5, ≥ 1–3 DWPD, e.g. Micron 7450/7500 MAX or Kioxia CM7-V) | **RAID-0 or ZFS stripe (~15 TB usable)** mounted at `/srv/build`. High sustained write endurance is critical for AOSP `out/` + `ccache`. |
| **Artifact & Mirror NVMe** | **2× 7.68 TB Enterprise U.2 / E3.S NVMe** (RAID-1, ~7.68 TB usable) | Mounted at `/srv/releases` for `releases/desktop-flash/`, WebInstaller `channels/`, `adevtool` factory image cache, and `repo` mirror. |
| **Networking** | **Dual 10GbE or 25GbE SFP28** (OCP 3.0 NIC, LACP bond) | Fast `repo sync`, Google factory image fetches, and S3/CDN artifact publishing. |
| **Out-of-Band Mgmt** | **iDRAC9 Enterprise** (dedicated management VLAN) | Remote console, Redfish telemetry (thermals, PSU, NVMe wear), and power control. |
| **Power** | **Dual Redundant 2400W Titanium PSUs** (dual PDU A+B feeds) | Dual 96-core EPYCs + NVMe under full build load draw ~1,100–1,400 W sustained. |

### Storage Sizing Breakdown (14 GuardTalkOS Targets)

| Directory | Mount | Estimated Size | Purpose |
| :--- | :--- | :--- | :--- |
| `/srv/build/worktree` | Scratch NVMe | ~350 GB | `repo` checkout (`nullset-zone/platform_manifest`, 1,034+ repos) + `vendor/google_devices/` |
| `/srv/build/worktree/out` | Scratch NVMe | ~400–800 GB (active) | Soong/Ninja build outputs (up to ~3.5 TB if retaining all 14 targets concurrently without `installclean`) |
| `/srv/build/ccache` | Scratch NVMe | 500 GB – 1 TB | Optional compiler cache (if enabled) |
| `/srv/releases/factory-cache` | Artifact NVMe (RAID-1) | ~100 GB | Stock Pixel factory images cached for `adevtool` |
| `/srv/releases/desktop-flash` | Artifact NVMe (RAID-1) | ~250 GB / release | Staged `*-latest` images + `SHA256SUMS` + `acks/*.ack` for 14 targets |
| `/srv/releases/web-installer` | Artifact NVMe (RAID-1) | ~250 GB / release | Packed 14-channel WebInstaller `channels/` + `dist/site/` |

---

## 2. Host OS, Filesystem & Kernel Tuning

### Operating System
- **Ubuntu 24.04 LTS Server** (minimal install, HWE kernel) or **Debian 12/13**.
- Create a dedicated non-root service user `builder` for all CI/CD jobs (`usermod -aG plugdev builder`).

### NVMe Array & Mount Options
Format the scratch NVMe RAID-0 with `ext4` (fast metadata ops for millions of small AOSP/Soong files) or `xfs`:

```bash
# Example: 4x NVMe mdadm RAID-0 for /srv/build
sudo mdadm --create /dev/md0 --level=0 --raid-devices=4 /dev/nvme1n1 /dev/nvme2n1 /dev/nvme3n1 /dev/nvme4n1
sudo mkfs.ext4 -m 1 -O dir_index,extent,sparse_super /dev/md0
```

`/etc/fstab` mount options:
```text
/dev/md0  /srv/build     ext4  defaults,noatime,nodiratime,commit=60,discard=async  0 2
/dev/md1  /srv/releases  ext4  defaults,noatime,nodiratime                          0 2
tmpfs     /tmp           tmpfs defaults,noatime,nosuid,nodev,size=64G               0 0
```

> **Swap safety net:** Configure a **64 GB NVMe swapfile** on `/srv/build/swapfile` (`vm.swappiness=1`) to prevent sudden OOM-killer aborts during peak ThinLTO / `r8` / `metalava` memory spikes.

### `sysctl` & Resource Limits

`/etc/sysctl.d/99-aosp-build.conf`:
```ini
fs.inotify.max_user_watches = 1048576
fs.inotify.max_user_instances = 8192
fs.file-max = 2097152
vm.max_map_count = 1048576
vm.swappiness = 1
vm.dirty_ratio = 20
vm.dirty_background_ratio = 5
```

`/etc/security/limits.d/99-builder.conf`:
```text
builder soft nofile 1048576
builder hard nofile 1048576
builder soft nproc  65536
builder hard nproc  65536
```

Apply with `sudo sysctl --system`.

---

## 3. Required Host Packages

```bash
sudo apt-get update && sudo apt-get install -y \
  git git-lfs curl wget aria2 rsync jq bc bison flex gperf \
  build-essential ccache zip unzip lz4 zstd pigz pbzip2 \
  python3 python3-pip python3-venv \
  e2fsprogs android-sdk-libsparse-utils \
  openssl libssl-dev libncurses6 libncurses-dev \
  libelf-dev liblz4-tool xxd cpio \
  nodejs npm nvme-cli smartmontools

# Install yarn (required by vendor/adevtool)
sudo npm install -g yarn

# Install repo tool
sudo curl -fsSL https://storage.googleapis.com/git-repo-downloads/repo -o /usr/local/bin/repo
sudo chmod 0755 /usr/local/bin/repo
```

> Verify Node.js is **v20 LTS or newer** (required by `vendor/adevtool` and `vendor/guardtalk/web-installer`).

---

## 4. Concurrency Tuning for 192 Cores / 512 GB RAM

On a 192-core / 384-thread machine with 512 GB RAM, **2.67 GB RAM per physical core** (1.33 GB per thread) is the main constraint during link/Dex/LTO phases. Do **not** run unbounded `-j384`:

| Phase | Recommended Flag / Setting | Reason |
| :--- | :--- | :--- |
| `repo sync` | `repo sync -j16 --no-tags --optimized-fetch` | Avoids GitHub rate limits while saturating 10GbE. |
| Soong / Ninja (`m`) | `m -j128` (up to `-j160` once validated) | Leaves headroom for parallel `lld` ThinLTO + JVM (`r8`/`metalava`) peaks within 512 GB RAM. |
| Java Heap (`_JAVA_OPTIONS`) | `export _JAVA_OPTIONS="-Xmx16g"` | Prevents `r8`/`metalava` OOM without starving native linkers. |
| Build Concurrency | **1 Android target build at a time** per runner | A single `m -j128` saturates the 192-core host cleanly; running 2 simultaneous AOSP builds risks OOM. |
| WebInstaller / QA | Can run concurrently with idle cores or post-build | Lightweight (`npm test`, `verify_*.sh`, `debugfs` scans). |

---

## 5. Security & Signing-Key Management

1. **Signing keys are NEVER committed to git.** `vendor/guardtalk/branding/signing-keys/` is gitignored for all `.pem` and `.pk8` files.
2. **Runner isolation:**
   - **CI Runner (PR / branch verification):** Runs with ephemeral/dev keys or unsigned verification builds; has **zero access** to production signing keys.
   - **Release Runner (protected tags / manual dispatch only):** Mounts production signing keys (`avb.pem`, `releasekey.pk8`, `platform.pk8`, `media.pk8`, `networkstack.pk8`, `shared.pk8`, `bluetooth.pk8`, `nfc.pk8`, `sdk_sandbox.pk8`, `gmscompat_lib.pk8`, `testkey.pk8`) from an encrypted vault/HSM volume into `vendor/guardtalk/branding/signing-keys/` (`chmod 0700` dir, `0600` files) only for the duration of the signing step, then unmounts/shreds ephemeral copies.
3. **Key generation & runbook:** See `vendor/guardtalk/scripts/generate-signing-keys.sh` and `vendor/guardtalk/branding/signing-keys/RUNBOOK.md`.
4. **Network egress:** Restrict CI server inbound access to management/VPN only; outbound allowed to `github.com/nullset-zone`, `android.googlesource.com`, `dl.google.com` (for `adevtool`), and your release artifact bucket/CDN.

---

## 6. GuardTalkOS CI/CD Pipeline Stages

### Supported 14 Pixel Targets (`*-cur-user`)

| Family | Kernel | Device Codenames |
| :--- | :--- | :--- |
| **Pixel 10 (Laguna)** | `6.6` | `blazer`, `frankel`, `mustang`, `rango` |
| **Pixel 9 (Zuma Pro)** | `6.1` | `caiman`, `comet`, `komodo`, `tegu`, `tokay` |
| **Pixel 8 (Zuma)** | `6.1` | `akita`, `husky`, `shiba` |
| **Pixel 9a / Tablet** | `6.1` | `stallion`, `tangorpro` |

*(Emulator target `emu64a` is also available under `vendor/guardtalk/device/emu64a/` for automated smoke tests.)*

### Pipeline Steps

#### Stage 1 — Sync Source Tree
```bash
mkdir -p /srv/build/worktree && cd /srv/build/worktree
repo init -u https://github.com/nullset-zone/platform_manifest.git -b 16-qpr2
repo sync -j16 --no-tags --optimized-fetch --force-sync
```

#### Stage 2 — Generate Proprietary Vendor Blobs (`adevtool`) + GuardTalk Hooks
```bash
source build/envsetup.sh
yarn --cwd vendor/adevtool install --frozen-lockfile

for dev in akita blazer caiman comet frankel husky komodo mustang rango shiba stallion tangorpro tegu tokay; do
  adevtool generate-all -d "$dev"
  # Re-apply GuardTalk BoardConfig / product hooks per:
  # vendor/guardtalk/device/REGEN_HOOKS.md
done
```

#### Stage 3 — Clean Build (`*-cur-user`)
```bash
source build/envsetup.sh
for dev in akita blazer caiman comet frankel husky komodo mustang rango shiba stallion tangorpro tegu tokay; do
  rm -f out/soong/soong.*.variables out/soong/soong.*.extra.variables
  lunch "${dev}-cur-user"
  m installclean
  m -j128 target-files-package otatools
done
```

#### Stage 4 — Sign, Stage & Verify AVB/Hashes
- Sign release outputs using `vendor/guardtalk/scripts/sign-build.sh` (with protected signing keys mounted).
- Stage per-device images into `/srv/releases/desktop-flash/${dev}-latest/` with `SHA256SUMS` and `acks/*.ack`.
- Verify AVB metadata (`Flags: 0`), `ro.build.type=user`, `ro.debuggable=0`, and zero `su` binaries.

#### Stage 5 — Automated Host QA & Acceptance Gates
Run from the workspace root:
```bash
# Check-in host verify + unittest suite
bash vendor/guardtalk/checkin/host/verify_host.sh
python3 -m unittest discover -s vendor/guardtalk/checkin/host -p 'test_*.py' -v

# Product acceptance scripts
vendor/guardtalk/scripts/verify-radio-excision.sh
vendor/guardtalk/scripts/verify-voice-filter.sh
vendor/guardtalk/scripts/verify-face-filter.sh
vendor/guardtalk/scripts/verify-bt-vintf-excision.sh

# Static/host QA verify scripts
for s in vendor/guardtalk/docs/qa/verify_*.sh; do
  bash "$s"
done
```

#### Stage 6 — WebInstaller 14-Channel Packing & Verification
```bash
cd vendor/guardtalk/web-installer
npm ci
bash scripts/pack-wizard-hosted-channels.sh
bash scripts/build-site.sh
npm test
node scripts/readiness-gate.mjs
bash scripts/verify-flashall.sh
```

---

## 7. Monitoring, Alerting & Maintenance

| Metric | Tool | Alert Threshold |
| :--- | :--- | :--- |
| **NVMe Wear (`Percentage Used`) & Media Errors** | `nvme smart-log /dev/nvme*` via `node_exporter` | Warn ≥ 70% wear; Critical ≥ 85% or any media error |
| **Disk Usage (`/srv/build`, `/srv/releases`)** | `node_exporter` | Warn ≥ 80%; Critical ≥ 90% (auto-prune old `out/`) |
| **CPU Package Temps & Fan/PSU Health** | Dell iDRAC9 Redfish exporter | Warn ≥ 85 °C; Critical PSU redundancy loss |
| **RAM & OOM Killer Events** | `node_exporter` + `dmesg` / `journald` | Alert on any `Out of memory: Killed process` event |
| **Signing Key Backup** | Encrypted off-box cold storage | Verified quarterly; **never** stored on `/srv/build` RAID-0 |
