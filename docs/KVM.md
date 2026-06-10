# KVM setup for GuardTalk emulator (headless Ubuntu)

The Android emulator needs **hardware acceleration** on x86_64 Linux. Without it,
boot can take 30–60+ minutes or fail for ARM64 images.

## Check if KVM is already installed

```bash
# CPU supports virtualization
grep -E 'vmx|svm' /proc/cpuinfo   # vmx = Intel VT-x, svm = AMD-V

# Kernel module loaded
lsmod | grep kvm

# Device node exists
ls -la /dev/kvm
```

On this server, KVM is **already installed** (`kvm_intel` loaded, `/dev/kvm` present).
The usual problem is **permissions**, not missing packages.

## Install KVM packages (if modules missing)

```bash
sudo apt update
sudo apt install -y qemu-kvm cpu-checker
sudo modprobe kvm
sudo modprobe kvm_intel   # Intel CPUs
# sudo modprobe kvm_amd   # AMD CPUs
```

Verify:

```bash
kvm-ok    # from cpu-checker; should say "KVM acceleration can be used"
```

## Grant your user access (required on this host)

`/dev/kvm` is typically `root:kvm` mode `660`. Add yourself to `kvm`:

```bash
sudo gpasswd -a $USER kvm
```

Then **log out and back in** (new SSH session is enough):

```bash
# must show kvm in the list
groups
test -r /dev/kvm && test -w /dev/kvm && echo "KVM OK"
```

## Run GuardTalk emulator after KVM works

```bash
cd /path/to/GrapheneOS-worktree
HEADLESS=1 WIPE=1 vendor/guardtalk/scripts/run-emulator.sh
# auto-picks guardtalk_emu64x on x86_64 without KVM; uses emu64a if KVM works and you override
```

With KVM, boot should complete in a few minutes. Without KVM, use `guardtalk_emu64x`
only (not `guardtalk_emu64a` — ARM64 QEMU needs KVM on x86 hosts).

## Nested virtualization (cloud VMs)

If `kvm-ok` fails inside a cloud VM, enable **nested virtualization** in the
hypervisor (AWS, GCP, Proxmox, etc.) or run the build host on bare metal.
