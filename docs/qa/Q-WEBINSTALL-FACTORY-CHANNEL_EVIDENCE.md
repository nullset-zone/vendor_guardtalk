# Q-WEBINSTALL-FACTORY-CHANNEL Evidence

**Task:** Q-WEBINSTALL-FACTORY-CHANNEL  
**QA run:** 2026-08-20T15:37:00Z–2026-08-20T15:42:17Z (independent re-run; did **not** trust T completion report)  
**Artifact under test (read-only):** `vendor/guardtalk/scripts/pack-webinstall-channel.sh`  
**Also read-only:** `vendor/guardtalk/web-installer/schema/`, `scripts/flash-from-remote.sh`, `vendor/guardtalk/scripts/flash-from-remote.sh`  
**Not edited:** packer, web-installer, `stage-rango-release.sh`, both flash scripts, `releases/`  
**Live flash:** **not attempted** — no live-flash PASS claimed  
**QA status:** **REVIEW only** (never APPROVED)

## Governance

- GIP-0 VERIFIED: workflow `.windsurf/workflows/aegis-qa.md`, inbox `TO_QA.md`, both Q cards, PROTOCOL/ROLES, memory-bank, AGENTS.md.
- Prompt-injection shield: SAFE (risk 0%).
- Gate -1: first `gate_enforcer` check failed (`guardian_consulted` missing). `ask_guardian` returned fallback (`Guardian Proxy not available`; `governanceStatus=review_required`). Retry Gate -1 **PASSED**.
- Law 9: Guardian proxy unavailable; proceeded with local fallback + written evidence (do not stop).
- Packet path lock: writes only under `vendor/guardtalk/docs/qa/`, `TO_ARCHITECT.md`, both `TASK_QUEUE.md`. Memory-bank write skipped (not in packet allowlist).

## Environment

| Item | Independent observation |
|------|-------------------------|
| Host | Linux, cwd `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree` |
| `latest` | symlink `tokay-20260725-102506` → `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/releases/desktop-flash/tokay-20260725-102506` |
| `rango-latest` | symlink `rango-20260802-130756` (exists; used only as reject target) |
| Live out | `/tmp/qa-webinstall-263963` (not committed) |
| `.git` | **absent** at worktree root — git history of `stage-rango-release.sh` is HOLD, not invented |

---

## Check matrix

| ID | Check | Expected | Actual | Verdict |
|----|-------|----------|--------|---------|
| C1 | `--self-test` | exit 0, `SELF_TEST_OK` | exit 0, `SELF_TEST_OK` (tokay pack + rango reject + production fail-closed + pem reject) | **PASS** |
| C2 | Live `--stamp releases/desktop-flash/latest --out /tmp/qa-webinstall-263963` | `PACK_OK`, pointer `20260725-102506 1784975106 tokay dev` | same; 5 files; 28K (`du -sh`) | **PASS** |
| C3 | `--verify` on live out | `VERIFY_OK files=19` | `VERIFY_OK … files=19` (18 blobs noted “not staged”; `avb_pkmd.bin` hashed) | **PASS** |
| C4 | `--verify` + `--verify-stamp releases/desktop-flash/latest` | `VERIFY_OK files=19` | `VERIFY_OK … files=19` (no “not staged” lines — all hashes checked) | **PASS** |
| C5 | `CHANNEL=production` pack | fail closed, exit ≠ 0 | exit 1: `CHANNEL=production cannot pack: no in-tree public signer (fail closed)` | **PASS** |
| C6 | `--channel production` pack | fail closed | exit 1: same fail-closed text | **PASS** |
| C7 | `CHANNEL=production --verify` on live hash-only out | fail closed | exit 1: `CHANNEL=production requires a public .sig (fail closed)` | **PASS** |
| C8 | Pack `releases/desktop-flash/rango-latest` | reject non-tokay | exit 1: `product 'rango' is not in the advertised allowlist (tokay only)` | **PASS** |
| C9 | Secrets in emitted `--out` | no `*.pem` / `*.pk8` / `.env` / `BEGIN PRIVATE` | named-secret count 0; `NO_BEGIN_PRIVATE`; `avb_pkmd.bin` is binary (1032 B), no PEM text | **PASS** |
| C10 | Schema `advertisedDevices` tokay only; rango absent | schema items const `tokay`; no rango | `items.const=tokay`; `rango in schema json=False`; example `["tokay"]`; `reservedProducts=["akita"]` only | **PASS** |
| C11 | Live manifest allowlist | `advertisedDevices=["tokay"]`; no rango | product tokay; advertised `['tokay']`; `has_rango=False`; `channelLabel=dev/unlocked`; `verifiedBootClaim=none`; `factoryZip=None` | **PASS** |
| C12 | Both `flash-from-remote.sh` identical | `cmp` silent + IDENTICAL | `FLASH_SCRIPTS_IDENTICAL`; both 1135 lines | **PASS** |
| C13 | `stage-rango-release.sh` not QA edit target | QA did not edit | QA did not write this file. mtime `2026-08-20 06:38:04Z` (before packer mtime `15:30:43Z`). Git history **HOLD** (no `.git`) | **PASS** (QA) / **HOLD** (T-edit proof via git) |
| C14 | No 2 GiB zip in `--out` (metadata-only default) | no `*.zip`; max file ≪ 2 GiB | `ZIP_COUNT=0`; max file 4405 B (`manifest.json`); total 7739 B; `du -sh` 28K | **PASS** |
| C15 | Independent SHA-256 of all 19 SUMS vs stamp | all MATCH | 19/19 MATCH; `INDEPENDENT_HASH_MISMATCH=0` | **PASS** |
| C16 | Pointer epoch vs stamp name | `date -u -d '2026-07-25 10:25:06' +%s` = 1784975106 | 1784975106; `date -u -d @1784975106` = Sat Jul 25 10:25:06 UTC 2026 | **PASS** |
| C17 | Adversarial: tamper first SHA256SUMS digest | `--verify-stamp` fail | exit 1: `SHA256 mismatch: avb_pkmd.bin` | **PASS** |
| C18 | Adversarial: inject `BEGIN PRIVATE KEY` into `files.txt` | verify fail | exit 1: `private key material in channel dir: files.txt` | **PASS** |
| C19 | Adversarial: drop `evil.pem` into channel dir | verify fail | exit 1: `secret-shaped file in channel dir: evil.pem` | **PASS** |
| C20 | No live-flash PASS | no device flash commands | none run | **PASS** (honesty) |
| C21 | `WEB_INSTALLER_CHANNEL.md` illustrative epoch | docs nit only | example `20260725-102506 1753439106 tokay dev` — `1753439106` is 2025-07-25, not live 1784975106 | **WARN** (docs; not packer FAIL) |

**Overall (host/static):** **PASS** with **WARN** (illustrative epoch in CHANNEL.md) and **HOLD** (no `.git` to prove T did not edit `stage-rango-release.sh`; no live-flash).

---

## Raw command output

### C1 — `--self-test`

```text
$ vendor/guardtalk/scripts/pack-webinstall-channel.sh --self-test
PACK_OK  pointer=20990101-000000 4070908800 tokay dev
PACK_OK  out=/tmp/tmp.z597lkxsaW/out-tokay  copies_images=0  dry_run=0
PACK_OK  dev/unlocked  verifiedBootClaim=none  factoryZip=null
verify: hash recorded, blob not staged: boot.img
verify: hash recorded, blob not staged: bootloader.img
verify: CHANNEL=dev hash-only (signature not required)
VERIFY_OK  pointer=20990101-000000 4070908800 tokay dev  files=3
WARN: ignoring secret-shaped file in stamp (will not publish): evil.pk8
SELF_TEST_OK
SELF_TEST_EXIT=0
```

### C2 — live pack

```text
$ vendor/guardtalk/scripts/pack-webinstall-channel.sh --stamp releases/desktop-flash/latest --out /tmp/qa-webinstall-263963
PACK_OK  pointer=20260725-102506 1784975106 tokay dev
PACK_OK  out=/tmp/qa-webinstall-263963  copies_images=0  dry_run=0
PACK_OK  dev/unlocked  verifiedBootClaim=none  factoryZip=null
PACK_EXIT=0
```

### C3 — `--verify` (metadata-only out)

```text
$ vendor/guardtalk/scripts/pack-webinstall-channel.sh --verify /tmp/qa-webinstall-263963
verify: hash recorded, blob not staged: boot.img
verify: hash recorded, blob not staged: bootloader.img
verify: hash recorded, blob not staged: dtbo.img
verify: hash recorded, blob not staged: init_boot.img
verify: hash recorded, blob not staged: product.img
verify: hash recorded, blob not staged: pvmfw.img
verify: hash recorded, blob not staged: radio.img
verify: hash recorded, blob not staged: super_empty.img
verify: hash recorded, blob not staged: system.img
verify: hash recorded, blob not staged: system_dlkm.img
verify: hash recorded, blob not staged: system_ext.img
verify: hash recorded, blob not staged: vbmeta.img
verify: hash recorded, blob not staged: vbmeta_system.img
verify: hash recorded, blob not staged: vbmeta_vendor.img
verify: hash recorded, blob not staged: vendor.img
verify: hash recorded, blob not staged: vendor_boot.img
verify: hash recorded, blob not staged: vendor_dlkm.img
verify: hash recorded, blob not staged: vendor_kernel_boot.img
verify: CHANNEL=dev hash-only (signature not required)
VERIFY_OK  pointer=20260725-102506 1784975106 tokay dev  files=19
VERIFY_EXIT=0
```

Observation (not FAIL): metadata-only `--verify` still exits 0 after recording 18 missing blobs, because `avb_pkmd.bin` is present and hashed. Full blob check requires `--verify-stamp` (C4).

### C4 — `--verify` + `--verify-stamp`

```text
$ vendor/guardtalk/scripts/pack-webinstall-channel.sh --verify /tmp/qa-webinstall-263963 --verify-stamp releases/desktop-flash/latest
verify: CHANNEL=dev hash-only (signature not required)
VERIFY_OK  pointer=20260725-102506 1784975106 tokay dev  files=19
VERIFY_STAMP_EXIT=0
```

### C5 / C6 / C7 — production fail-closed

```text
$ CHANNEL=production vendor/guardtalk/scripts/pack-webinstall-channel.sh --stamp releases/desktop-flash/latest --out /tmp/qa-webinstall-prod-$$
PROD_PACK_EXIT=1
ERROR: CHANNEL=production cannot pack: no in-tree public signer (fail closed)

$ vendor/guardtalk/scripts/pack-webinstall-channel.sh --channel production --stamp releases/desktop-flash/latest --out /tmp/qa-webinstall-prodflag-$$
PRODFLAG_PACK_EXIT=1
ERROR: CHANNEL=production cannot pack: no in-tree public signer (fail closed)

$ CHANNEL=production vendor/guardtalk/scripts/pack-webinstall-channel.sh --verify /tmp/qa-webinstall-263963
PROD_VERIFY_EXIT=1
ERROR: CHANNEL=production requires a public .sig (fail closed)
```

### C8 — rango-latest reject

```text
$ ls -la releases/desktop-flash/rango-latest
lrwxrwxrwx ... releases/desktop-flash/rango-latest -> rango-20260802-130756

$ vendor/guardtalk/scripts/pack-webinstall-channel.sh --stamp releases/desktop-flash/rango-latest --out /tmp/qa-webinstall-rango-$$
RANGO_PACK_EXIT=1
ERROR: product 'rango' is not in the advertised allowlist (tokay only)
```

### C9 / C14 — secrets + no 2 GiB zip

```text
SECRET_NAMED_COUNT=0
NO_BEGIN_PRIVATE
ZIP_COUNT=0
1517 /tmp/qa-webinstall-263963/SHA256SUMS
1032 /tmp/qa-webinstall-263963/avb_pkmd.bin
4405 /tmp/qa-webinstall-263963/manifest.json
37 /tmp/qa-webinstall-263963/tokay-dev
748 /tmp/qa-webinstall-263963/files.txt
MAX_FILE_BYTES=4405
OVER_2GIB=False
TOTAL_BYTES=7739
28K	/tmp/qa-webinstall-263963   # du -sh (directory metadata)
file avb_pkmd.bin: data
AVB_NO_PEM_TEXT
```

### C10 / C11 — allowlist

Schema `advertisedDevices`:

```json
{"type":"array","minItems":1,"maxItems":1,"items":{"const":"tokay"},"description":"Public allowlist. tokay only."}
```

`rango in schema json=False`. Example and live manifest: `advertisedDevices=["tokay"]`, `reservedProducts=["akita"]`, `product=tokay`. Live `has_rango=False`.

Live pointer:

```text
20260725-102506 1784975106 tokay dev
```

Live SHA256SUMS (19 lines) — independently re-hashed against stamp (C15): all MATCH.

### C12 — flash scripts

```text
$ cmp -s scripts/flash-from-remote.sh vendor/guardtalk/scripts/flash-from-remote.sh && echo FLASH_SCRIPTS_IDENTICAL
FLASH_SCRIPTS_IDENTICAL
  1135 scripts/flash-from-remote.sh
  1135 vendor/guardtalk/scripts/flash-from-remote.sh
```

### C13 — stage-rango

```text
stat: 2026-08-20 06:38:04.175658687 +0000 vendor/guardtalk/scripts/stage-rango-release.sh
stat: 2026-08-20 15:30:43.611958752 +0000 vendor/guardtalk/scripts/pack-webinstall-channel.sh
.git: No such file or directory
```

QA did not edit `stage-rango-release.sh`. Cannot `git log`/`git diff` this worktree.

### C16 — epoch

```text
$ date -u -d '2026-07-25 10:25:06' +%s
1784975106
$ date -u -d @1784975106
Sat Jul 25 10:25:06 AM UTC 2026
$ date -u -d @1753439106
Fri Jul 25 10:25:06 AM UTC 2025
```

### C17–C19 — adversarial tamper (copies under `/tmp` only)

```text
tampered first line: 7728e30f50bfa5cea165f473175a08803f6a8346642b5aa10913e9d9e6defef0  avb_pkmd.bin
TAMPER_EXIT=1
ERROR: SHA256 mismatch: avb_pkmd.bin

PRIV_INJECT_EXIT=1
ERROR: private key material in channel dir: files.txt

PEM_INJECT_EXIT=1
ERROR: secret-shaped file in channel dir: evil.pem
```

---

## Acceptance criteria map

| Criterion | Verdict |
|-----------|---------|
| Evidence file with PASS/FAIL/HOLD per check + raw output | **PASS** (this file) |
| Independent `--self-test` and live verify | **PASS** (C1–C4) |
| rango/non-tokay reject, production fail-closed, no secrets, tokay allowlist | **PASS** (C5–C11, C8) |
| No live-flash PASS | **PASS** (C20) |
| TO_ARCHITECT.md REPLACE; Q status REVIEW in both queues | see completion contract (written after this file) |

---

## Coverage gaps / HOLDs

- `--copy-images` not re-run (would only symlink; default metadata-only path was the acceptance target).
- No live device flash. Do not invent on-device PASS.
- Worktree has no `.git`; T-edit history of `stage-rango-release.sh` cannot be proven from git. mtime evidence only.
- Docs nit: `vendor/guardtalk/docs/WEB_INSTALLER_CHANNEL.md` L60 illustrative pointer uses 2025 epoch `1753439106` (Architect already noted). Packer live pointer is correct.

## Bugs found

- None that fail the packer acceptance criteria.
- WARN only: CHANNEL.md illustrative epoch year-off (2025 vs 2026).

## PQE Assessment: Code Entropy LOW

Packer is a linear bash pipeline: parse stamp → tokay allowlist → secret scan → hash → write metadata → optional verify. Fail-closed branches for rango, production, and PEM/PRIVATE are explicit. Metadata-only `--verify` skipping missing images is documented behavior, not hidden control flow.

## Ultimate Critique Score

- `ultimate_critique`: **TOOL UNAVAILABLE** (`python: not found`)
- `self_critique`: 91/100 (false Law 5 on documenting PEM reject-path tests; no secrets emitted)
- `hallucination_guard` paranoid: recommendedAction PASS / L0_GROUNDED; tool also flagged low grounding-score noise
- Manual Gate 5 (10 criteria): **94%** — proceed (score ≥ 80)
- `reasoning_self_refine`: TOOL UNAVAILABLE (unknown tool after schema fetch); manual Law 7/8 refine used

## Live flash

**Not attempted. No live-flash PASS.**
