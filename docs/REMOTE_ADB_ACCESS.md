---
doc: REMOTE ADB / FASTBOOT ACCESS
applies_to: Cursor IDE on operator laptop (Pixel Tablet attached by USB) + oss-compute-1 cloud workspace
status: VERIFIED — server-side capabilities tested 2026-10-18
boot_verified: false
---

# Reaching the Pixel Tablet from the cloud workspace

## The topology

```
OPERATOR LAPTOP                        CLOUD WORKSPACE
  (IDE + Pixel Tablet via USB)           oss-compute-1
  adb server :5037                       adb client, fastboot 36.0.1
  192.168.10.11            ──SSH──▶     192.168.2.220
```

The tablet is **USB-attached to the laptop**. The agents run **on the cloud host**, which has no USB visibility.
Nothing here can "see" the device until a channel is opened **from the laptop toward the cloud host**.

## Verified server-side capabilities (2026-10-18, re-runnable)

| Capability | Result |
|---|---|
| `adb` | ✅ v34.0.4 (distro) **and** v36.0.1 at `out/host/linux-x86/bin/adb` |
| `fastboot` | ✅ **v36.0.1 at `out/host/linux-x86/bin/fastboot`** (not on PATH; distro has none) |
| bind loopback TCP | ✅ tested `adb -P 5137` → `LISTEN 127.0.0.1:5137` |
| incoming SSH | ✅ `SSH_CONNECTION=192.168.10.11 54653 192.168.2.220 22` |
| `usbip` client | ✅ `/usr/bin/usbip`, `/usr/bin/usbipd` |
| **`vhci-hcd` kernel module** | ❌ **NOT loaded** |
| **root to load it** | ❌ **no passwordless sudo** (uid 1001) |

## Option A — `adb` over an SSH reverse tunnel  ✅ RECOMMENDED

No root, no kernel modules, no firewall change. Run the adb **server** on the laptop; the cloud host is a **client**.

**On the laptop:**
```bash
adb start-server                       # Pixel must be in USB-debugging mode (adb devices shows it)
ssh -R 5037:127.0.0.1:5037 oss-c1@192.168.2.220
```

**On the cloud host** (the shell an agent controls):
```bash
export ADB_SERVER_SOCKET=tcp:127.0.0.1:5037
adb devices -l                         # should now list the Pixel Tablet
adb shell getprop ro.product.device    # expect: tangorpro
adb shell getprop ro.build.version.release
```

Notes:
- Use the **repo's** adb for version parity with fastboot: `out/host/linux-x86/bin/adb`.
- If the tunnel must outlive the interactive shell, add `-N -f` and set `ExitOnForwardFailure=yes` so a failed
  bind is loud rather than silent.
- `adb` protocol is **version-sensitive**; a 34 server + 36 client generally works, but matching 36/36 is safest.

**What this does NOT give you:** `fastboot`. Fastboot is a raw USB protocol with no TCP transport — an adb tunnel
cannot carry it. Flashing therefore requires Option B, or flashing from the laptop.

## Option B — USB/IP  ⛔ BLOCKED on this host (needs an admin action)

USB/IP is the *only* way to make `fastboot` reach a cloud host, because it presents the device as a **real USB
device** over the network. It requires root on the cloud side to load `vhci-hcd`, which this account lacks.

An administrator of the cloud host must run:
```bash
sudo modprobe vhci-hcd usbip-host
# optionally persist:
echo -e "vhci-hcd\nusbip-host" | sudo tee /etc/modules-load.d/usbip.conf
```

**On the laptop:**
```bash
usbipd -D                                        # start the USB/IP daemon
usbip list -l                                    # find the Pixel's busid
usbip bind -b <busid>
```

**On the cloud host** (once `vhci-hcd` is loaded):
```bash
usbip attach -r <laptop-reachable-ip> -b <busid>
out/host/linux-x86/bin/fastboot devices
```

⚠ Laptop and cloud host must be **mutually routable** for this; behind NAT, tunnel the usbipd port
(`3240`) over SSH as well: `ssh -L 3240:127.0.0.1:3240 oss-c1@...` then `usbip attach -r 127.0.0.1`.

⚠ Changing USB state (adb → fastboot) re-enumerates the device, breaking the attach. Re-attach after each mode
switch.

## Option C — flash from the laptop

If the goal is simply to test a build, prefer the operator flashing from the laptop with the released bundle. This
sidesteps both tunnels entirely and keeps the destructive step under the operator's direct control.

## Security notes (Law 4)

- Both options forward a **privileged control channel**. Bind the tunnel to **loopback only**
  (`127.0.0.1:5037`), never `0.0.0.0`.
- `adb` has **no authentication** — anyone who reaches port 5037 controls the device. Treat the tunnel as a
  credential.
- Prefer a dedicated SSH key for the tunnel, not a shared interactive login.
- Do **not** leave a reverse tunnel up unattended; `adb` sessions survive disconnects inconsistently.

## What this unblocks for the programme

With Option A live, the agent can at last execute the **on-device** cards that are currently `HOLD` — e.g.
`adb shell getprop` assertions in `Q-PORT-TANGORPRO`, `Q-PORT-TANGORPRO-EXCISION-VACUITY`, and
`verify-radio-excision.sh`.

**But note:** `BOOT_VERIFIED=false` still stands. Device *visibility* is not device *proof*, and there is still
**no GuardTalk product tree and no built image** to flash. The tunnel makes verification **possible**; it does not
make a build exist.

---

# ⚙️ Operational setup (2026-10-27) — the port-squatting fix + persistent tunnel

## The defect that broke every previous attempt

`adb` on the **cloud host** auto-starts a local server on `127.0.0.1:5037`. That server then **owns** the port, so
your `ssh -R 5037:...` fails with `remote port forwarding failed` — and the failure looks like "no device"
rather than "port taken". It happened twice.

**Verified behaviour** (proved by test): when `ADB_SERVER_SOCKET` is set, the adb *client* connects to that socket
and **does not spawn a local server**. So the fix is twofold:

1. **Reserve 5037.** `~/.bashrc` now exports `ANDROID_ADB_SERVER_PORT=5038`, so local adb uses **5038** and can
   never take 5037 again.
2. **Always drive the tunnel through a helper** that sets `ADB_SERVER_SOCKET` — never a bare `adb` call.

## Cloud side (this host)

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree

./scripts/adb-remote.sh status              # tunnel + device diagnostics, tells you what's wrong
./scripts/adb-remote.sh                     # adb devices -l via the tunnel
./scripts/adb-remote.sh shell getprop ro.product.device
ADB_TUNNEL_PORT=5038 ./scripts/adb-remote.sh devices
```

`status` distinguishes the two failure modes:

| `owner` | verdict | meaning |
|---|---|---|
| `ssh`/`sshd` | ✅ real reverse tunnel | good |
| `adb` | ⚠ local server squatting | `pkill -f 'adb.*fork-server'` — your `ssh -R` would fail |
| (nothing listening) | ❌ no tunnel | start one from the Mac |

## Mac side — install once, then it is automatic

```bash
# pull the installer
scp oss-c1@192.168.2.220:/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/scripts/mac/install-adb-tunnel.sh .

chmod +x install-adb-tunnel.sh
./install-adb-tunnel.sh
```

It sets up:
- **`autossh`** (auto-reconnect; installed via Homebrew if missing)
- a **launchd LaunchAgent** `dev.guardtalk.adbtunnel` — `RunAtLoad` + `KeepAlive`, so the tunnel survives
  sleep, logout and reboot
- log at `~/Library/Logs/guardtalk-adb-tunnel.log`

One-off alternative (no persistence):

```bash
adb start-server
ssh -R 5037:127.0.0.1:5037 -o ExitOnForwardFailure=yes -N oss-c1@192.168.2.220
```

Stop / remove:

```bash
launchctl unload ~/Library/LaunchAgents/dev.guardtalk.adbtunnel.plist
rm ~/Library/LaunchAgents/dev.guardtalk.adbtunnel.plist
```

## ⛔ What this still cannot do

**It does not enable remote flashing.**

| Need | Tunnel? | Why |
|---|---|---|
| `adb shell`, `logcat`, `getprop`, `pm list` | ✅ works | adb is a TCP protocol |
| **`fastboot flash`** | ❌ **impossible** | fastboot talks **raw USB** to the bootloader. A Pixel in fastboot mode is **not running Android**, so `adbd` is not up either — the tunnel would show nothing at all. |

Also confirmed **server→Mac is closed**: every probed port on the Mac is filtered (22/88/445/5900/62078/3283), so
the cloud host cannot initiate anything toward your Mac. **The Mac must always initiate.**

**Flashing therefore happens on the Mac, over USB** — see
`releases/desktop-flash/tangorpro-20261018-123446/README-FLASH-DESKTOP.md`.

---

# 🎯 OPTION D (BEST) — let CURSOR carry the tunnel

**This is the recommended setup.** Cursor's "Connect to Host via SSH" uses your normal `~/.ssh/config`. A
`RemoteForward` entry there is applied on **every** connection — so the tunnel comes up **by itself** whenever
Cursor connects. No second terminal, no manual `ssh -R`, nothing to forget after a reboot or reconnect.

## On your Mac (one time)

```bash
scp oss-c1@192.168.2.220:/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/scripts/mac/setup-cursor-adb-tunnel.sh .

chmod +x setup-cursor-adb-tunnel.sh
./setup-cursor-adb-tunnel.sh            # dry-run — prints the block, writes nothing
./setup-cursor-adb-tunnel.sh --apply    # write it
```

It appends this to `~/.ssh/config` (idempotent — replaces its own managed block on re-run):

```sshconfig
Host oss-compute-1
    HostName 192.168.2.220
    User oss-c1
    RemoteForward 5037 127.0.0.1:5037
    ExitOnForwardFailure no
    ServerAliveInterval 30
    ServerAliveCountMax 3
```

Then **reconnect Cursor** (Command Palette → *Remote: Close Remote Connection*, then reconnect). That's it.

## Why `ExitOnForwardFailure no` (important)

If the server-side 5037 is already taken, `no` keeps the **Cursor connection alive**; `yes` would kill the whole
SSH session and disconnect your editor. We detect the failure from the server side instead:

```bash
./scripts/adb-remote.sh status      # owner=sshd/ssh => ✅ ; owner=adb => squatting
```

## Server-side prerequisites — DONE (2026-10-27)

| Requirement | State |
|---|---|
| `sshd AllowTcpForwarding` | ✅ `yes` |
| `sshd GatewayPorts` | ✅ `no` → binds **loopback only** (correct; not network-exposed) |
| Port 5037 reserved for the tunnel | ✅ `/etc/environment` + `/etc/profile.d/guardtalk-adb.sh` set `ANDROID_ADB_SERVER_PORT=5038`, so a bare `adb` can never squat 5037 |
| `scripts/adb-remote.sh` | ✅ always sets `ADB_SERVER_SOCKET`; `status` diagnoses the three failure modes |

## Verify from the server

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
./scripts/adb-remote.sh status
# expected:  owner : sshd (or ssh)
#            verdict: ✅ a real SSH reverse tunnel
#            List of devices attached
#            <serial>  device  product:tangorpro ...
```

## ⚠ The one thing that will still confuse you

If the tablet is in **FASTBOOT** mode, `adb devices` shows **nothing** — even with a perfect tunnel. Fastboot
mode does not run Android, so `adbd` is not up. That is expected; it is not a tunnel failure.
Return to Android with `fastboot reboot` to test the tunnel.

---

# 🔑 OPTION E — give the SERVER a shell on the Mac (the only way to flash remotely)

**This is what makes `fastboot flash` possible from the cloud host.**

## Why this is necessary

`fastboot` is **raw USB**. It has no TCP transport, and a Pixel bootloader exposes no network endpoint. macOS has
**no USB/IP server**, so the device cannot be exported either. The tablet is physically on your Mac.

Therefore the only way a remote box can flash it is to **run `fastboot` on the Mac**. That needs a shell on the
Mac — and the tunnel to get one is carried by **Cursor's own SSH connection**.

## The mechanism (proven on 2026-10-27)

```
Cursor on Mac  ──SSH──▶  cloud server
                 ▲
                 └── RemoteForward 2222 127.0.0.1:22
                     ⇒ Mac's sshd appears on the server's loopback :2222
                     ⇒ server can: ssh -p 2222 <you>@127.0.0.1  → run fastboot
```

**Verified end-to-end** (using the server as a stand-in for the Mac):

```
$ ssh -N -R 2222:127.0.0.1:22 oss-c1@127.0.0.1 &
  ✅ :2222 BOUND — RemoteForward works
$ ssh -p 2222 oss-c1@127.0.0.1 'echo TUNNEL_OK; id -un; hostname'
  TUNNEL_OK
  oss-c1
  oss-compute-1
```

## Setup — on your Mac

### Step 1. Enable Remote Login (needs your admin password)

```
System Settings → General → Sharing → Remote Login → ON
```
(or `sudo systemsetup -setremotelogin on`)

"Allow access for: Only these users" is fine and safer.

### Step 2. Run the setup script

```bash
scp oss-c1@192.168.2.220:/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/scripts/mac/setup-mac-exec.sh .

chmod +x setup-mac-exec.sh
./setup-mac-exec.sh            # checks only, writes nothing
./setup-mac-exec.sh --apply    # applies
```

It does three things:
1. verifies Remote Login is ON,
2. authorises the **server's** key (`SSH-ED25519 …guardtalk-build@oss-compute-1`, fingerprint
   `SHA256:HjI8tOIwzpiCWC4KAMnj87z9v5+AQh4MasC3orrm+fo`) in your `~/.ssh/authorized_keys`,
3. writes this managed block into `~/.ssh/config`:
   ```sshconfig
   Host oss-compute-1
       HostName 192.168.2.220
       User oss-c1
       RemoteForward 2222 127.0.0.1:22
       ExitOnForwardFailure no
       ServerAliveInterval 30
       ServerAliveCountMax 3
   ```

### Step 3. Reconnect Cursor

Command Palette → **Remote: Close Remote Connection** → reconnect.
That single reconnect is what applies the forward.

## Use — from the server

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree

./scripts/mac-exec.sh status            # tunnel + Mac identity + fastboot devices
./scripts/mac-exec.sh run 'uname -a'    # any command on the Mac
./scripts/mac-exec.sh fastboot devices  # fastboot on the Mac

./scripts/mac-exec.sh flash --dry-run   # show the full plan
./scripts/mac-exec.sh flash             # pull→verify→flash→boot verdict
```

`flash` does, in order:
1. `rsync` the 2.6 GB bundle to the Mac **over the tunnel**
2. verify **SHA256SUMS on the Mac**
3. show `fastboot devices` + bootloader lock state
4. **refuse if the bootloader is locked** (test-key image would be rejected)
5. flash: bootloader → reboot → pvmfw/boot/init_boot/vendor_boot/vendor_kernel_boot/dtbo →
   system/system_ext/product/vendor/vendor_dlkm/system_dlkm → `avb_custom_key` → `vbmeta` → `-w` → reboot
6. wait for **`sys.boot_completed=1`** (never `adb devices`)

**Config:** set `MAC_USER=<your-mac-username>` if detection fails.

## ⚠ Security — read this

Exposing the Mac's sshd on the server's loopback means **anyone with this server account can log into your Mac**
while the tunnel is up. Mitigations already in place:
- bound to **loopback only** (`GatewayPorts no`) — not reachable from the network,
- `ExitOnForwardFailure no` so a port clash cannot silently kill it,
- the tunnel dies when you close Cursor.

To revoke at any time: remove the `guardtalk-build` line from `~/.ssh/authorized_keys` on the Mac, and/or
`launchctl`-free — just delete the managed block from `~/.ssh/config` and reconnect.

## ⚠ If `fastboot devices` is empty

The tablet may be in **Android** mode rather than fastboot. From the server:

```bash
./scripts/mac-exec.sh run 'adb devices -l'
./scripts/mac-exec.sh run 'adb reboot bootloader'
```

Or hold **Power + Volume Down** while powering on.
