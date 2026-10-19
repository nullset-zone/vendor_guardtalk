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
