# GuardTalkOS WebInstaller — PROGRESS

Last gate: 2026-08-23 · `npx tsc --noEmit` exit 0 · `npx tsc -p tsconfig.lib.json --noEmit` exit 0 · `tsx --test --test-timeout=60000 test/*.test.ts` **291 pass / 0 fail / 1 skip** · `npm run routes:build` emits `dist/site` · curl of `/install/`, `install-app.js`, sibling routes, `/threat-model/`, and the 42-module import graph all **200**.

## Custom-key spine (this wave)

- `proveVbmetaUserSigned` proves every planned vbmeta against the enrolled pkmd **before any write**. Wired in `runFlashPlan` and `runUpdateFlow` (no more hardcoded `signedWithUserKey: true`).
- New stop `USER_ANCHOR_MISMATCH`: "vbmeta is not signed with your enrolled key — flash refused".
- Flow 1: re-imported handle must be `extractable === false`; `pkmd` is returned for enrolment. Flow 2 zeroises byte copies of n/e/d after the BigInt signer is built (BigInt `d` cannot be wiped — documented platform limit).
- Encrypted backup passphrase floor: **≥12 characters**.
- `/install` bootstrap (`install-app.ts`) holds key material in memory and calls `onPageHide` cleanup.
- Update step 5 reports the **live** lock readout. It no longer claims the bootloader "has stayed open since the first install."
- `/threat-model` is a real static page. Update CSS is `../styles-route.css` (the old `/install.css` hole is gone).

## What is ready

- AVB signer (SHA256_RSA4096) byte-parity vs `external/avb/avbtool.py` (D-014).
- Fastboot client: H1 budget, H2 refuse-oversize, H3 INFO drain.
- Flash order: `avb_custom_key` first → firmware → OS → user-signed vbmeta last.
- State machine: no timer advance; deserialize rejects forged completions.
- Offline static site under `dist/site` (`scripts/build-site.sh`).
- Claim-lint / CSP D-006 on emitted markup. `LIVE_FLASH_CLAIMED` remains `false`.

## Launch flags (human, not this session)

| Flag | Current | Flip when |
|------|---------|-----------|
| `LIVE_FLASH_CLAIMED` (`src/types.ts`) | `false` | After a real device flash you witnessed |
| `status.json.flashCapability.liveFlashClaimed` | `false` | Same |
| `PRE_LAUNCH` / `RELEASE_STATE` | `alpha` | Human launch decision |

Automated tests stay simulated (D-011). Capability is implemented; the claim stays false until you flash.

## Still open (honest alpha, not flash-spine)

- Q-01…Q-14 — brand/onion/partition-layout still `// confirm`. The release public key (Q-04) is **picked as a PEM** at step 2; it is not baked in.
- First live WebUSB flash has not been witnessed. Serve `dist/site`, walk `/install?sim=1` first, then a real tokay with your key.
