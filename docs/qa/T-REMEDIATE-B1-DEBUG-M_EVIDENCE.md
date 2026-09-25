# Evidence — T-REMEDIATE-B1-DEBUG-M

**Task:** `T-REMEDIATE-B1-DEBUG-M` (DEC-011 / DEC-013 / DEC-014)  
**Date:** 2026-09-18T11:54:47Z  
**Agent:** BACKEND_ENGINEER (Panel 2)  
**Device:** Pixel 9 Pro XL (`komodo`)  
**Verdict:** **REVIEW** — r3 lunch **EXIT=0**; r3 `m` **BUILD_EXIT=0**.  
`out/.../system/build.prop` **this `m`**: `ro.build.type=userdebug` (mtime 2026-09-18 11:28:52Z).  
Never APPROVED. **FLASH_READY=false**. **DEBUG_FLASH_READY=false** (no pack).  
**USB_GO=false**. **PASS HOLD remains.**

GIP-0 / Gate -1 in-process YAML. Guardian MCP/HTTP **not called**. Derived
`.agent-comm/TASK_QUEUE.md` **not** edited. No commit. No pack. No `avb.pem`.
No `lunch komodo-trunk_staging-user`.

## DEC-014 javadoc (this continue)

`{@code */*}` closes a Java block comment at the lexer. `{@literal */*}` would
too. Rewrote to plain words. `createViewIntent` body **unchanged**.

- `GuardTalkHtmlViewerLaunch.java:54` — "Not a catch-all MIME and not a launcher."
- `GuardTalkMediaPreview.java:33` — same token in the allowed `guardtalk/` dir;
  rewritten the same way (would have failed ninja next).

## r3 lunch + `m`

| Item | Value |
|------|-------|
| Combo | `komodo-trunk_staging-userdebug` |
| LUNCH_EXIT | **0** |
| TARGET_PRODUCT | `komodo` |
| TARGET_BUILD_VARIANT | `userdebug` |
| TARGET_BUILD_TYPE | `release` |
| BUILD_KEYS | `test-keys` (allowed on sidecar) |
| M_START | 2026-09-18T11:27:16Z |
| M_END | 2026-09-18T11:49:47Z |
| Duration | 22:31 (mm:ss) |
| **BUILD_EXIT** | **0** |
| Log line | `#### build completed successfully (22:31 (mm:ss)) ####` |
| Wrapper | `/tmp/t-remediate-b1-debug-m-wrapper-r3.sh` |
| Log | `T-REMEDIATE-B1-DEBUG-M_M-r3.log` / `/tmp/t-remediate-b1-debug-m-20260918T112650Z.log` |
| Meta | `T-REMEDIATE-B1-DEBUG-M_META-r3.txt` |

Session-only `GIT_CONFIG` `safe.directory` = `vendor/adevtool`. No `git config` write.

## `build.prop` (this `m`, not Sept 15)

```
out/target/product/komodo/system/build.prop
mtime: 2026-09-18 11:28:52.317616251 +0000
ro.build.type=userdebug
ro.build.tags=test-keys
ro.build.flavor=mainline-userdebug
ro.build.id=BP4A.260205.002
```

`ro.build.date` still shows the tree `BUILD_DATETIME` pin (Jul 2 2026). File
mtime is 2026-09-18 — this `m` rewrote the prop.

## Prior rounds (not this image)

| Round | BUILD_EXIT | Blocker |
|-------|------------|---------|
| r1 10:22:11Z | 1 | kati dex_preopt `service-devicelock` — closed by DEC-013 |
| r2 10:35:08Z | 1 | DocumentsUI:54 javadoc — closed by DEC-014 |

## Forbidden rematch

| Action | Result |
|--------|--------|
| USB GO / flash / lock / wipe | **not run**; `adb devices -l` empty |
| pack / `komodo-debug-*` | **ABSENT** |
| retarget `komodo-latest` | **unchanged** → `komodo-20260915-063833` |
| keygen / `avb.pem` | **not run**; `find vendor/guardtalk` `*.pem`/`*.pk8` empty |
| `FLASH_READY=true` | **absent** |
| `DEBUG_FLASH_READY=true` | **absent** (pack not this card) |
| git commit | **not run** |
| change `createViewIntent` behavior | **not done** |

## Acceptance rematch

| # | Criterion | Result |
|---|-----------|--------|
| 1 | lunch EXIT=0; komodo / userdebug | **PASS** |
| 2 | `m` EXIT=0 | **PASS** (r3 BUILD_EXIT=0) |
| 3 | `build.prop` `ro.build.type=userdebug` from **this** `m` | **PASS** (mtime 2026-09-18 11:28:52Z) |
| 4 | Evidence (BUILD_EXIT, lunch vars, no USB) | **PASS** |
| 5 | No USB; no APPROVED; flags not invented true | **PASS** |

DEBUG_FLASH_READY stays **false** until T-DEBUG-PACK + Q. Q-REMEDIATE-B1-DEBUG-M
stays BLOCKED until Architect APPROVE (DEC-012).
