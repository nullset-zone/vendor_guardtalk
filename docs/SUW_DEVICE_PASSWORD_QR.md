# SUW Device Password QR Field (`device_password`)

**Task:** `T-SUW-LOCK-APPLY` (Backend) — consumed by Syndicate QR mint tooling and `F-SUW-LOCK-UI` (Community interactive password)  
**Decision:** `DEC-SUW-LOCK-001`  
**Date:** 2026-07-24

## Purpose

During Setup Wizard, establish the device unlock **password** for Syndicate members from a signed provisioning QR. The field lives inside the Ed25519-signed inner JSON so an attacker cannot strip or alter it without failing signature verification.

Community members do **not** use this QR field; they set a password on a dedicated SUW page (`CommunityLockActivity`, Frontend) that calls the same apply helper API.

## Credential policy

- Type: `CREDENTIAL_TYPE_PASSWORD` only (`LockscreenCredential.createPassword`)
- Honor `vendor/guardtalk/docs/PASSWORD_ONLY_LOCK_POLICY.md` / `ro.guardtalk.password_only_lock=1`
- Do **not** mint or apply PIN / pattern credentials

## Wire format (unchanged envelope)

Outer envelope (same as GuardTalkConfig / ProvisionQrActivity today):

```json
{
  "payload": "<base64(UTF-8 inner JSON)>",
  "signature": "<base64(Ed25519 signature over the UTF-8 inner JSON bytes)>"
}
```

Optional URI prefix: `guardtalk://` before the JSON object.

### Inner JSON

| Field | Required | Notes |
|-------|----------|-------|
| `secure_level` | yes | `syndicate` or `community` |
| `wifi_ssid` | yes | GMP SSID |
| `wifi_password` | no* | WPA passphrase (*product may require) |
| `vpn_server` | yes | IKEv2 host |
| `vpn_identity` | no* | |
| `vpn_psk` | no* | |
| `private_dns` | no | |
| `connectivity_server` | no | |
| **`device_password`** | **yes for syndicate** | UTF-8 unlock password; non-empty after trim |

Signature is computed over the **entire** inner JSON UTF-8 bytes, including `device_password`. Do not weaken Ed25519 checks.

### Quality rules (fail-closed)

| Rule | Behavior |
|------|----------|
| Missing / empty / whitespace-only | Reject parse (Syndicate SUW + GuardTalkConfig syndicate) |
| Length &lt; 4 | Reject (`LockPatternUtils.MIN_LOCK_PASSWORD_SIZE`) |
| Lock set fails | Provisioning fails; SUW Next stays disabled |

## Out-of-tree mint tooling notes

1. Hold the Ed25519 **private** seed **out of tree only** (never commit; never put in KDoc, source, or in-tree docs). Archive the seed outside the git tree (operator secret store / Architect out-of-tree archive).
2. Build inner JSON with a strong unique `device_password` per device (or per cohort, per ops policy).
3. UTF-8 encode inner JSON → sign with Ed25519 → base64 payload + signature.
4. Compiled PUBLIC key locations (must match each other; rotate together):
   - `packages/apps/SetupWizard2/java/app/grapheneos/setupwizard/view/activity/ProvisionQrActivity.kt` — `TEST_PUBLIC_KEY`
   - `vendor/guardtalk/apps/GuardTalkConfig/src/com/guardtalk/config/QrPayloadParser.kt` — `TEST_PUBLIC_KEY`
5. After any key rotation (e.g. H1 `T-SUW-QR-KEY-ROTATE`), re-mint all Syndicate QRs with the new out-of-tree private seed; old signatures will fail verify.
6. Never log or echo `device_password` or the private seed in mint logs, adb, or QR labels beyond the signed payload itself.

## In-tree consumers

| Component | Role |
|-----------|------|
| `DevicePasswordApplier` (SetupWizard2) | Shared apply helper for SUW (Syndicate QR + Community UI) |
| `ProvisionQrActivity` | Parse/verify → require `device_password` → apply before Next |
| `QrPayloadParser` / `ConfigApplier` / `DevicePasswordApplier` (GuardTalkConfig) | Schema + apply parity |

## Secrets handling

- Never log plaintext unlock secrets
- Zero `LockscreenCredential` buffers after `setLockCredential`
- Fail closed: missing field, bad signature, or lock-set failure → no provision success

## Rollback (Law 11)

1. Remove `device_password` requirements from parsers/appliers and revert SUW apply helper wiring.
2. Restore prior string copy for provision success if desired.
3. Rebuild: `m SetupWizard2 GuardTalkConfig -j$(nproc)`.
4. Existing device passwords remain until changed by the user; no userdata migration.

## Verification

```bash
cd /mnt/Big-Storage/GuardTalk/GrapheneOS-worktree
rg -n 'device_password' packages/apps/SetupWizard2 \
  vendor/guardtalk/apps/GuardTalkConfig \
  vendor/guardtalk/docs/SUW_DEVICE_PASSWORD_QR.md
rg -n 'Ed25519|verifyEd25519|signature' \
  packages/apps/SetupWizard2/java/app/grapheneos/setupwizard/view/activity/ProvisionQrActivity.kt \
  vendor/guardtalk/apps/GuardTalkConfig/src/com/guardtalk/config/QrPayloadParser.kt
source build/envsetup.sh && lunch tokay-trunk_staging-userdebug
m SetupWizard2 GuardTalkConfig -j$(nproc)
```
