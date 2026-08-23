# Q-WEBINSTALL-GOS-ANALYSIS Evidence

**Task:** Q-WEBINSTALL-GOS-ANALYSIS  
**QA run:** 2026-08-20T15:18:49Z–2026-08-20T15:21:00Z (independent re-fetch; did **not** trust T completion report)  
**Artifact under test (read-only):** `vendor/guardtalk/docs/WEB_INSTALLER.md` (416 lines; QA did not edit)  
**Depends on:** T-WEBINSTALL-GOS-ANALYSIS APPROVED  
**Live flash:** **not attempted** — no live-flash PASS claimed  
**QA status:** **REVIEW only** (never APPROVED)

## Governance

- GIP-0 VERIFIED: workflow `.windsurf/workflows/aegis-qa.md`, inbox `TO_QA.md`, both Q cards, PROTOCOL/ROLES, memory-bank, AGENTS.md.
- Prompt-injection shield: SAFE (risk 0%).
- Gate -1: first `gate_enforcer` check failed (`guardian_consulted` missing). `ask_guardian` returned fallback (`Guardian Proxy not available`; `governanceStatus=compliant`; “You may proceed”). Retry Gate -1 **PASSED**.
- Law 9: Guardian proxy unavailable; proceeded with local fallback + written evidence (do not stop).

## Independent fetch log

Fetched 2026-08-20T15:18:49Z into `/tmp/q-webinstall-gos/` (not committed).

| Ref | URL | HTTP | Local artifact |
|-----|-----|------|----------------|
| W1 | https://grapheneos.org/install/web | 200 | `w1.html` (25367 B) |
| W2 | https://raw.githubusercontent.com/GrapheneOS/grapheneos.org/main/static/install/web.html | 200 | `web.html` (27467 B) |
| W3 | https://raw.githubusercontent.com/GrapheneOS/grapheneos.org/main/static/js/web-install.js | 200 | `web-install.js` (16196 B) |
| W4 | https://api.github.com/repos/GrapheneOS/grapheneos.org/contents/static/js/fastboot/ffe7e270 | 200 | `w4-tree.json` |
| W4 vendor | https://api.github.com/repos/GrapheneOS/grapheneos.org/contents/static/js/fastboot/ffe7e270/vendor | 200 | `w4-vendor.json` |
| W5 | https://api.github.com/repos/kdrag0n/fastboot.js/commits/ffe7e270061b95fe0f0f3abd1aa7d3c28999d1d9 | 200 | `w5-commit.json` |
| W5 html | https://github.com/kdrag0n/fastboot.js/commit/ffe7e270061b95fe0f0f3abd1aa7d3c28999d1d9 | 200 | (HEAD only) |
| W6 | https://raw.githubusercontent.com/kdrag0n/fastboot.js/ffe7e270061b95fe0f0f3abd1aa7d3c28999d1d9/src/factory.ts | 200 | `factory.ts` (11580 B) |
| W7 | https://raw.githubusercontent.com/kdrag0n/fastboot.js/ffe7e270061b95fe0f0f3abd1aa7d3c28999d1d9/src/factory-optimized.ts | 200 | `factory-optimized.ts` (9759 B) |
| W8 | https://raw.githubusercontent.com/kdrag0n/fastboot.js/master/LICENSE | 200 | `w8-license` (MIT, Danny Lin 2021) |
| W9 | https://raw.githubusercontent.com/kdrag0n/fastboot.js/ffe7e270061b95fe0f0f3abd1aa7d3c28999d1d9/package.json | 200 | `package.json` |
| W10 | https://grapheneos.org/install/cli | 200 | `w10.html` (32303 B) |
| W11 | https://raw.githubusercontent.com/GrapheneOS/device_common/16-qpr2/generate-factory-images-common.sh | 200 | `generate-factory-images-common.sh` (15252 B) |
| W12 | https://raw.githubusercontent.com/GrapheneOS/script/16-qpr2/generate-release.sh | 200 | `generate-release.sh` (10091 B) |
| W13 | https://releases.grapheneos.org/tokay-stable | 200 | body `2026081300 1786591653 tokay stable` |
| W14 | https://releases.grapheneos.org/allowed_signers | 200 | 104 B (not “200 bytes”) |
| W15 | https://grapheneos.org/releases | 200 | `w15.html` |
| W16 | https://raw.githubusercontent.com/GrapheneOS/grapheneos.org/main/LICENSE | 200 | © 2014–2026 GrapheneOS MIT |
| W17 | https://raw.githubusercontent.com/nodeca/pako/master/LICENSE | 200 | MIT |
| W18 | https://raw.githubusercontent.com/gildas-lormeau/zip.js/master/LICENSE | 200 | BSD-3-Clause |
| GOS fork README | https://raw.githubusercontent.com/GrapheneOS/fastboot.js/main/README.md | **404** | confirms ADR deny |

HEAD-only (no zip download):

| URL | HTTP | Content-Length |
|-----|------|----------------|
| https://releases.grapheneos.org/tokay-install-2026081300.zip | 200 | 2001076770 |
| https://releases.grapheneos.org/tokay-install-2026081300.zip.sig | 200 | 310 |
| https://releases.grapheneos.org/tokay-factory-2026081300.zip | 404 | 146 |
| https://releases.grapheneos.org/sha256sums | 404 | 146 |
| https://releases.grapheneos.org/SHA256SUMS | 404 | 146 |
| https://releases.grapheneos.org/tokay-install-2026081300.zip.sha256 | 404 | 146 |
| https://releases.grapheneos.org/tokay-alpha | 200 | `2026081300 1786591653 tokay alpha` |
| https://releases.grapheneos.org/tokay-beta | 200 | `2026081300 1786591653 tokay beta` |

---

## Mandatory checks (Architect packet)

| ID | ADR claim | Independent source | Verdict |
|----|-----------|--------------------|---------|
| M1 | W3 import `./fastboot/ffe7e270/fastboot.min.mjs` | W3 L3: `import * as fastboot from "./fastboot/ffe7e270/fastboot.min.mjs";` | **PASS** |
| M2 | `supportedDevices` order `stallion, rango, mustang, blazer, frankel, tegu, comet, komodo, caiman, tokay, akita, husky, shiba, felix, tangorpro, lynx, cheetah, panther, bluejay, raven, oriole` | W3 L243 exact array | **PASS** |
| M3 | Quota threshold `2000 * 1024 * 1024` (and ≠ 0) | W3 L476: `estimate.quota !== 0 && estimate.quota < 2000 * 1024 * 1024` | **PASS** |
| M4 | IndexedDB `BlobStore` | W3 L7 `CACHE_DB_NAME = "BlobStore"`; L125 `indexedDB.open`; L128 `createObjectStore("files", { keyPath: "name" })`; L137–139 `{name, blob}` | **PASS** |
| M5 | Unlock FAIL = user rejected | W3 L230–234 `flashing unlock`; `error.status === "FAIL"` | **PASS** |
| M6 | Lock FAIL = user rejected | W3 L356–360 `flashing lock`; same FAIL handling | **PASS** |
| M7 | `flashFactoryZip(blob, true, reconnectCallback, …)` | W3 L323–324 | **PASS** |
| M8 | `RELEASES_URL = https://releases.grapheneos.org` | W3 L5 | **PASS** |
| M9 | W5 `ffe7e270` is a real kdrag0n/fastboot.js commit | GitHub API sha `ffe7e270061b95fe0f0f3abd1aa7d3c28999d1d9`; html_url 200; committer Daniel Micay; message “factory-optimized: adjust FlashScript parser… Zip entries are now contained in an outer directory.” | **PASS** |
| M10 | W13 `{product}-stable` first token = release id (tokay) | Body `2026081300 1786591653 tokay stable`; W3 L253 `metadata.split(" ")[0]` → zip `{product}-install-{releaseId}.zip` | **PASS** |
| M11 | ADR does **not** contain verbatim `This is the WebUSB-based installer for GrapheneOS` | `rg` on ADR: no match. Sentence **is** in official W2 L40 and live W1. | **PASS** |
| M12 | ADR does **not** claim OPFS as a GOS-called API | ADR: official text “does **not** name OPFS”; “Official OPFS API use \| **None found** in W3”. W1/W2/W3: `OPFS`/`opfs` count 0. W3 uses IndexedDB + `navigator.storage.estimate()`. | **PASS** |
| M13 | ADR keeps rango **hidden**; tokay MVP | ADR L11, L116, L255–257, L380–390, L400: tokay only advertised; rango hidden/experimental; not web allowlist. | **PASS** |
| M14 | No private key material | ADR: no `-----BEGIN`, no `.pk8`, no `.pem`, no private OpenSSH. Public `avb_pkmd.bin` + published sha256 only. W14 public signer line only. | **PASS** |
| M15 | No live-flash PASS | No device attached; no flash commands run. | **PASS** (honesty) |

---

## Additional GOS behavior claims (citation honesty)

| ID | ADR claim | Source | Verdict |
|----|-----------|--------|---------|
| A1 | W4 vendor tree `fastboot.min.mjs`, `.map`, `vendor/pako_inflate.min.js`, `vendor/z-worker-pako.js` | W4 API names: those two files + `vendor/` dir; vendor dir = `pako_inflate.min.js`, `z-worker-pako.js` | **PASS** |
| A2 | `configureZip` inflate workers | W3 L459–463 exact paths | **PASS** |
| A3 | Unlock: `getvar unlocked` / skip if `yes` | W3 L224 `getVariable("unlocked") === "yes"` | **PASS** |
| A4 | Download: product must be in `supportedDevices`; GET `{RELEASES_URL}/{product}-stable` | W3 L246–251 | **PASS** |
| A5 | Snapshot cancel if status ≠ `none` | W3 L315–317 | **PASS** |
| A6 | Remove key = `erase:avb_custom_key` | W3 L343 | **PASS** |
| A7 | XHR `responseType=blob` (not fetch) for progress | W3 L53–57 | **PASS** |
| A8 | Wake lock + `beforeunload` while busy | W3 L25–36, L496–499 | **PASS** |
| A9 | No WebUSB → buttons unavailable + prerequisites | W3 L465–492 `"usb" in navigator` | **PASS** |
| A10 | QuotaExceeded → incognito/quota message | W3 L397–399 | **PASS** |
| A11 | Comment “factory images then ~1700 MiB” | W3 L474 `Currently factory images are ~1700MiB` | **PASS** |
| A12 | W9 `android-fastboot` 1.1.1 MIT; deps zip.js + pako | `package.json` name/version/license/repository + deps | **PASS** |
| A13 | GrapheneOS/fastboot.js default-branch README | HTTP **404** | **PASS** (denied, as ADR) |
| A14 | W6 legacy AVB **after** OS images | `factory.ts` L331–352: flash image zip then `erase:avb_custom_key` + `avb_pkmd.bin` | **PASS** |
| A15 | W6 dispatches to W7 when `*/script.txt` present | `factory.ts` L216–218 | **PASS** |
| A16 | W7 opcodes: check-requirements, check-var, erase, flash [other-slot], maybe-cancel-snapshot-update, reboot-bootloader, run-cmd, toggle-active-slot | `factory-optimized.ts` L216–281 | **PASS** |
| A17 | W7 erase skipped unless wipe **or** partition is `avb_custom_key` | L101–108 | **PASS** |
| A18 | W11 flash-all order: dual-slot bootloader → radio → erase/flash AVB → uart/fips/dpm → `-w --skip-reboot update` | `generate-factory-images-common.sh` L193–268 | **PASS** |
| A19 | W11 min fastboot `35.0.1`; product must match `$DEVICE` | L98, L161–167 | **PASS** |
| A20 | W11 Apache 2.0 header | L3 | **PASS** |
| A21 | W12 tokay: UART+FIPS+DPM; rango: UART+DPM, no FIPS | L56–66 | **PASS** |
| A22 | W12 `MAX_DOWNLOAD_SIZE` `0x10000000` for `rango\|mustang\|blazer\|frankel` else `0xf900000` | L181–184 | **PASS** |
| A23 | W12 `optimize-factory-image` → `{device}-install-{build}` | L187–189 | **PASS** |
| A24 | W12 `AVB_PKMD` always set; tangorpro has no radio | L63, L71 | **PASS** |
| A25 | W14 allowed_signers line | Exact match: `contact@grapheneos.org ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIUg/m5CoP83b0rfSCzYSVA4cw4ir49io5GPoxbgxdJE` | **PASS** |
| A26 | W10 ssh-keygen verify command | Live CLI page contains the quoted `-n "factory images"` command | **PASS** |
| A27 | W1 AVB hashes tokay / akita / rango | Live W1: Pixel 9 / Pixel 8a / Pixel 10 Pro Fold hashes match ADR table. **Not** present in raw W2 `web.html` (page-generated). ADR cites W1. | **PASS** |
| A28 | Browser/OS matrix (Win10/11, macOS 14/15/26, Arch, Debian 12/13, Ubuntu 22.04/24.04/25.04, Mint 21/22/LMDE6, ChromeOS, GrapheneOS, Android 14–17 Play Protect; Chromium/Vanadium/Chrome/Edge/Brave; Incognito forbidden; fwupd stop; Ubuntu Snap broken; Flatpak/Snap avoid) | W2 L105–154, L201–216, L249–253 | **PASS** |
| A29 | udev packages | W2 L201–202 `android-udev` / `android-sdk-platform-tools-common` | **PASS** |
| A30 | Channel bodies tokay-alpha/beta same id | Fetched; match ADR | **PASS** |
| A31 | Install zip size ~1.86 GiB | HEAD 2001076770 | **PASS** |
| A32 | SHA256SUMS / factory-zip public URLs 404 | HEAD 404 | **PASS** |
| A33 | W2 loads `redirect.js` + `web-install.js` | W2 L31–33 `[[js|/js/redirect.js]]` and `[[js|/js/web-install.js]]` | **PASS** |

---

## WARN / HOLD (not mandatory FAILs)

| ID | Item | Verdict | Note |
|----|------|---------|------|
| W-UNIT | ADR “~**2 GiB** free RAM and **32 GiB** free storage (W1)” | **WARN** | Official W2 L86–87: “at least **2GB** of free memory … and **32GB** of free storage space”. Same numbers; official unit is **GB**, not GiB. Behavior claim holds; unit label is not a verbatim official string. |
| W-W14 | ADR W14 “fetched 200” | **WARN** | HTTPS **200**; body **104 bytes**. Ambiguous wording, not a wrong signer. |
| H-SCRIPT | Gap analysis vs `flash-from-remote.sh` (1135 / `cmp` identical) | **HOLD** | Packet forbids reading either flash script. Not independently re-verified. Do not treat T’s 1135/`cmp` as QA-verified. |
| H-ZIP | Published tokay-install zip `script.txt` bytes | **HOLD** | Did not download 1.86 GiB zip. Sequence opcodes inferred from W11+W12 (as ADR states). Generator order **PASS** (A18). Interior of this release’s zip **not** byte-checked. |
| H-FLASH | On-device / live WebUSB flash | **HOLD** | Out of scope. No invent PASS. |
| H-GITROOT | `git diff --stat -- vendor/guardtalk/docs/WEB_INSTALLER.md` at workspace root | **HOLD** | Workspace root has no `.git`. `vendor/guardtalk` is a git repo; ADR is **untracked** (`?? docs/WEB_INSTALLER.md`); QA made no edit. |

---

## Adversarial / Law 7 checks

| Test | Expected | Actual | Status |
|------|----------|--------|--------|
| Marketing-paste exact sentence in ADR | absent | absent (present only in official W2/W1) | **PASS** |
| OPFS claimed as GOS API | must not | ADR denies; sources have zero OPFS tokens | **PASS** |
| rango offered as MVP / production-bootable | must not | hidden/experimental throughout | **PASS** |
| Private key / PEM / pk8 in ADR | must not | none | **PASS** |
| Trust T report without re-fetch | forbidden | all W3/W5/W13 facts re-fetched | **PASS** |
| Invent live-flash PASS | forbidden | HOLD only | **PASS** |
| Rewrite ADR | forbidden | untouched (416 lines; mtime pre-QA) | **PASS** |
| Product code under `web-installer/` | forbidden this Q | QA wrote evidence + queues only | **PASS** |

---

## Verdict

**Citation honesty: PASS with WARN** (GB vs GiB unit nit; W14 “200” ambiguity).  
Mandatory packet items (W3, W4/W5, quota, device list, no-marketing-paste, rango-hidden, no keys, no live-flash PASS): **all PASS**.  
CLI flash-script identity and live zip `script.txt`: **HOLD** (scope / size), not FAIL.

Architect may APPROVE the ADR’s official-source claims. QA status stays **REVIEW**.

---

## Raw verification commands

```text
$ test -f vendor/guardtalk/docs/qa/Q-WEBINSTALL-GOS-ANALYSIS_EVIDENCE.md && wc -l vendor/guardtalk/docs/qa/Q-WEBINSTALL-GOS-ANALYSIS_EVIDENCE.md
198 vendor/guardtalk/docs/qa/Q-WEBINSTALL-GOS-ANALYSIS_EVIDENCE.md

$ rg -n 'PASS|FAIL|HOLD' vendor/guardtalk/docs/qa/Q-WEBINSTALL-GOS-ANALYSIS_EVIDENCE.md
# 15 mandatory PASS (M1–M15); 33 additional PASS (A1–A33); 0 FAIL
# WARN: W-UNIT, W-W14; HOLD: H-SCRIPT, H-ZIP, H-FLASH, H-GITROOT

$ git diff --stat -- vendor/guardtalk/docs/WEB_INSTALLER.md || true
# workspace root: not a git repository (git printed --no-index usage)
# vendor/guardtalk: git diff --stat docs/WEB_INSTALLER.md → empty
# ADR still 416 lines; QA did not rewrite it
```

### Sample independent extracts (QA-owned)

```text
# W3
import * as fastboot from "./fastboot/ffe7e270/fastboot.min.mjs";
const RELEASES_URL = "https://releases.grapheneos.org";
const CACHE_DB_NAME = "BlobStore";
const supportedDevices = ["stallion", "rango", "mustang", "blazer", "frankel", "tegu", "comet", "komodo", "caiman", "tokay", "akita", "husky", "shiba", "felix", "tangorpro", "lynx", "cheetah", "panther", "bluejay", "raven", "oriole"];
let releaseId = metadata.split(" ")[0];
await device.flashFactoryZip(blob, true, reconnectCallback,
if (estimate.quota !== 0 && estimate.quota < 2000 * 1024 * 1024)

# W5
sha: ffe7e270061b95fe0f0f3abd1aa7d3c28999d1d9
committer: Daniel Micay
message: factory-optimized: adjust FlashScript parser to changed entry paths

# W13
2026081300 1786591653 tokay stable

# W14
contact@grapheneos.org ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIUg/m5CoP83b0rfSCzYSVA4cw4ir49io5GPoxbgxdJE
```
