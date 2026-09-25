# Evidence — T-REMEDIATE-B1-DEBUG-PACK

**Task:** `T-REMEDIATE-B1-DEBUG-PACK` (DEC-015 / DEC-016 / **DEC-017**)  
**Date:** 2026-09-18T18:30:00Z (DEC-017 honesty rewrite; no `m`)  
**Agent:** BACKEND_ENGINEER (Panel 2)  
**Device:** Pixel 9 Pro XL (`komodo`)  
**Verdict:** **REVIEW** — honesty rewrite only. Never APPROVED.  
**FLASH_READY=false**. **DEBUG_FLASH_READY=false**.  
**LIVE_FLASH_CLAIMED=false**. **USB_GO=false**.

GIP-0 / Gate -1 in-process YAML. Guardian MCP/HTTP **not called**. Derived
`.agent-comm/TASK_QUEUE.md` **not** edited. No commit. No USB. No `avb.pem`.
No `lunch komodo-trunk_staging-user`. No packaging-only `m` this continue.
`BUILD_DATETIME` and caimito prebuilts **not** dirtied. STALE_BAK **not**
copied. `komodo-latest` **not** retargeted.

## DEC-017 honesty (this continue)

Independent rematch (Law 7; not Architect dump-trust):

| Item | Live rematch 2026-09-18T18:28Z |
|------|--------------------------------|
| Stamp | `releases/desktop-flash/komodo-debug-20260918-180338/` **exists** |
| `komodo-debug-latest` | → `komodo-debug-20260918-180338` |
| `komodo-latest` | still → `komodo-20260915-063833` |
| SHA256SUMS | **20/20 OK** |
| USB / `adb devices -l` | empty |
| Another `m` | **not started** |

### Userspace is r3

`system.img` / `vendor.img` / `vbmeta.img` (and `product` / `system_ext` /
`init_boot` / `vendor_boot` / `vendor_dlkm`) on `out/` still have
**2026-09-18 ~11:28–11:49Z** mtimes from `T-REMEDIATE-B1-DEBUG-M` r3.
This continue did **not** rebuild userspace. Stamp copies of those files
have pack mtimes (~18:03Z) because they were staged, not recompiled.

### A/B four are current-tree kernel packaging

The four A/B images are **current-tree kernel packaging** of GrapheneOS
`caimito-kernels` prebuilts. They were **not** rebuilt as a kernel / dtbo /
pvmfw compile this continue.

r3/r3b logs (`T-REMEDIATE-B1-DEBUG-PACK_M-r3.log`, `_M-r3b.log`):

| Step | What the log actually says |
|------|----------------------------|
| r3 M1 | `ninja: no work to do.` then 16s `Target boot image` / `Target vendor_kernel_boot image` |
| r3b M2 | `ninja: no work to do.` then installed-path `dtbo.img` |
| r3b M3 | `ninja: no work to do.` then `Copy: out/target/product/komodo/pvmfw.img` (16s) |

That is a **packaging restamp**. This-session mtime is **not** a rebuild
claim (DEC-017).

### SHA equals Sept 15 leftovers (Law 8)

Live `sha256sum` of stamp **equals**
`/tmp/t-remediate-b1-debug-pack-stale-20260915` **equals** `out/`:

| File | SHA-256 |
|------|---------|
| `boot.img` | `449a6bc2ebd1650f07d15b3f2852a6aec94d0d2f4356c30809808d6e884810fc` |
| `vendor_kernel_boot.img` | `a12a9fbd7f320cc5c797bf88fcece23ce75e98167cc6763b854bdfb4e6870eb8` |
| `pvmfw.img` | `f7c5910e0bada491895519d3018cdc37164b5873ae46e1772bcee0dc7b84eee8` |
| `dtbo.img` | `742a1e192a0199e11b2176829f9d818f5de0ad16b40132fcc0b8e4f6b162e433` |

Pinned `BUILD_DATETIME=1782971948` + caimito prebuilts ⇒ **Law 8 same
bits**. Packaging-only ninja is expected to re-emit those leftover bytes.
**Do not claim those four were rebuilt this continue.** Do not dirty
`BUILD_DATETIME` or kernel prebuilts to mint a new hash.

r2 wrapper (`_M-r2.log`) already logged `HOLD_SAME_SHA` on all four and
`SESSION_OK=0`, then a later continue packed anyway. DEC-017 documents
that pack as current-tree packaging, not a kernel rebuild.

STALE_BAK was **not** copied into the stamp. Pack source was `out/`.
Bytes match leftovers because inputs did not change (Law 8), not because
Sept 15 files were restored.

## Prior rounds (history; not a rebuild claim)

### r1 (HOLD — DEC-016)

| Item | Value |
|------|-------|
| Start | 2026-09-18T14:49:33Z |
| Lunch | EXIT=0 `komodo` / `userdebug` / test-keys |
| Goals | `bootimage vendorkernelbootimage pvmfwimage dtbo.img` |
| BUILD_EXIT | **1** |
| Fail | `ninja: unknown target 'dtbo.img', did you mean 'mkdtboimg'?` |
| Log | `T-REMEDIATE-B1-DEBUG-PACK_M-r1.log` |

Four files were moved aside to `/tmp/t-remediate-b1-debug-pack-stale-20260915`
(Sept 15 SHA). Not restored into `out/` as the pack source.

### r2 (packaging restamp; HOLD_SAME_SHA)

| Item | Value |
|------|-------|
| Combo | `komodo-trunk_staging-userdebug` |
| LUNCH_EXIT | **0** |
| Duration | 17 seconds |
| BUILD_EXIT | **0** |
| Wrapper | logged `HOLD_SAME_SHA` ×4 then `SESSION_OK=0` |
| Log | `T-REMEDIATE-B1-DEBUG-PACK_M-r2.log` |

### r3 / r3b (packaging-only; DEC-016 continue)

Logs as tabled above. `pvmfwimage` is an empty ninja phony; r3b used
installed paths. `get_build_var INSTALLED_DTBOIMAGE_TARGET` printed empty
after nsjail. **Not** a this-continue kernel compile.

## Stamp

| Item | Value |
|------|-------|
| Path | `releases/desktop-flash/komodo-debug-20260918-180338/` |
| Pointer | `komodo-debug-latest` → `komodo-debug-20260918-180338` |
| Prior stamp | `komodo-debug-20260918-150847` left on disk (not latest) |
| `komodo-latest` | still → `komodo-20260915-063833` |
| SHA256SUMS | **20/20 OK** |
| `super.img` | omitted |
| pem/pk8 | **0** |

## Forbidden rematch

| Action | Result |
|--------|--------|
| USB GO / flash / lock / wipe | **not run**; `adb devices -l` empty |
| retarget `komodo-latest` | **unchanged** → `komodo-20260915-063833` |
| copy STALE_BAK into stamp | **not done** |
| another packaging-only `m` | **not started** |
| dirty `BUILD_DATETIME` / caimito prebuilts | **not done** |
| `FLASH_READY=true` | **absent** |
| `DEBUG_FLASH_READY=true` | **absent** |
| git commit | **not run** |

## Acceptance rematch (DEC-017)

| # | Criterion | Result |
|---|-----------|--------|
| 1 | README + evidence do **not** claim A/B four were rebuilt this continue | **this rewrite** |
| 2 | State SHA equals Sept 15 leftovers / current-tree packaging | **this rewrite** |
| 3 | Userspace is r3; Law 8 pinned `BUILD_DATETIME=1782971948` + caimito | **this rewrite** |
| 4 | Stamp + SHA256SUMS 20/20; `komodo-debug-latest` → that stamp | **PASS** (exists; HOLD on flash-ready) |
| 5 | `komodo-latest` still → `komodo-20260915-063833` | **PASS** |
| 6 | No USB; `FLASH_READY=false`; `DEBUG_FLASH_READY=false`; `USB_GO=false` | **PASS** |
