# Q-REMEDIATE-B6-FASTBOOT-RC — independent rematch (QA, Panel 4)

| Field | Value |
|---|---|
| **task_id** | `Q-REMEDIATE-B6-FASTBOOT-RC` |
| **pair** | `T-REMEDIATE-B6-FASTBOOT-RC` (REVIEW accepted 2026-09-19T16:18:00Z) |
| **DEC** | `DEC-REMEDIATE-019` |
| **owner_repository** | `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree` (`repository_id` = `grapheneos-worktree`) |
| **authoritative_task_path** | `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/TASK_QUEUE.md` (owner-root) |
| **status** | `REVIEW` (never `APPROVED`) |
| **scope** | Independent static + adversarial rematch; **host-static only**; no USB, no flash/lock/wipe, no `m`, no pack |
| **date** | 2026-09-19T16:30Z |
| **PASS HOLD** | **INTACT** — boot cause is **OPEN**; no on-device verdict |

> Ground-truth discipline (per the session's piped-output paraphrase hazard): every
> load-bearing fact below is grounded in `grep -c` counts, `sha256sum`, `debugfs`
> extraction of the **packed** images, `strings`, and the **Read** tool — never in
> paraphrased `rg` content lines. Raw command output is retained for the harness
> under `vendor/guardtalk/docs/qa/_artifacts/` where applicable.

---

## 0. Gate -1 (Guardian First) — in-process

Per the dispatch contract, Gate -1 was enforced **in-process** from owner-local
`.aegis/governance/`. **No** `aegis-verifier` / `ask_guardian` / `gate_enforcer`
MCP tool and no Guardian HTTP call was made.

| Artifact | Count | Source |
|---|---|---|
| Laws | **24** (`law_00`…`law_23`) | `.aegis/governance/laws/` |
| Gates | **11** (`gate_neg1`…`gate_09`) | `.aegis/governance/gates/` |

Gate -1 declared **PASS (in-process)** — read-only rematch within declared target
paths (`vendor/guardtalk/docs/qa/`, `.agent-comm/`). Laws applied: L0, L1, L6, L7,
L8, L10, L11, L16, L19. No source, sepolicy, or script file edited.

---

## 1. Method & independence

The Backend lane was **not dump-trusted**. Every claim was re-derived from the raw
artifacts. Because the **packed** stamp is what is on the device, and the packed
image is **not** the same build as `out/`, I extracted the relevant files out of the
**packed** images with `debugfs` and re-ran the analysis there.

Commands actually run by QA (selected, all host-side):

```bash
# symlink baseline
readlink -f releases/desktop-flash/komodo-latest releases/desktop-flash/komodo-debug-latest
# out/ counts
grep -c '^ro\.guardtalk\.' out/target/product/komodo/vendor/build.prop          # 35
grep -c '^ro\.guardtalk\.' out/target/product/komodo/system/build.prop          # 0
# packed truth (the image that is on the device)
debugfs -R "dump /build.prop /tmp/packed_vendor_build.prop"  <stamp>/vendor.img
debugfs -R "dump /etc/selinux/vendor_property_contexts /tmp/packed_vendor_property_contexts" <stamp>/vendor.img
debugfs -R "dump /etc/selinux/plat_property_contexts /tmp/packed_ctx/..."     <stamp>/system.img
debugfs -R "dump /etc/selinux/product_property_contexts /tmp/packed_ctx/..."  <stamp>/product.img
debugfs -R "dump /etc/selinux/system_ext_property_contexts /tmp/packed_ctx/..." <stamp>/system_ext.img
debugfs -R "dump /odm/etc/selinux/odm_property_contexts /tmp/packed_ctx/..."  <stamp>/vendor.img
grep -c '^ro\.guardtalk\.' /tmp/packed_vendor_build.prop                        # 35
grep -c '^[A-Za-z]'        /tmp/packed_vendor_build.prop                        # 292
# label census (raw-string-prefix test = semantics-independent; see §4)
python3 /tmp/b6_prefix_check_packed.py   # 0/35 ro.guardtalk have ANY prefix/exact entry; 36/292 unlabeled
# denial mechanism source
grep -n 'Do not have permissions to set|SELinux permission check failed' system/core/init/property_service.cpp
grep -n 'kInitContext|kVendorContext' system/core/init/subcontext.h
# packed image Dex markers
strings -a <stamp>/system.img  | grep -c -F 'DeviceLock APEX absent'                 # 1
strings -a <stamp>/system.img  | grep -c -F 'Landroid/devicelock/DeviceLockFrameworkInitializer;'  # 1
strings -a <stamp>/system.img  | grep -c -F 'registerServiceWrappers failed'         # 0
strings -a out/target/product/komodo/system.img | grep -c -F 'Landroid/devicelock/DeviceLockFrameworkInitializer;'  # 0
strings -a out/target/product/komodo/system.img | grep -c -F 'registerServiceWrappers failed'  # 1
# ABL provenance of the observed messages
strings -a <stamp>/bootloader.img | grep -c -F 'decrement active slot boot retry'   # 2
strings -a <stamp>/bootloader.img | grep -c -F 'BL1 requested'                       # 1
# no invented verdict / PASS HOLD
grep -n 'FLASH_READY=true' TASK_QUEUE.md            # only historical/negative contexts; §5810 forbids inventing it
```

---

## 2. Verdict per ranked hypothesis (H1–H4)

**There is no on-device capture artifact anywhere in the tree** (searched
`.agent-comm/`, `vendor/guardtalk/`, `runtime/`, `.memory-bank/`, `releases/` for
`System zygote died`, `DeviceLock APEX absent`, `*logcat*`, `*pstore*`, `*dmesg*`
→ only prose/evidence docs, no raw log). Therefore **no ranked hypothesis can be
marked PASS or FAIL from this host**; each is **HOLD** with its reasoning checked.

| # | Hypothesis | QA verdict | Grounding |
|---|---|---|---|
| **H1** | post-`boot` userspace / `system_server` critical-service crash | **HOLD** (leading, unproven) | Consistent with the bound facts (logo + `adbd` reached, then drop). No `FATAL`/`exit-info` artifact exists to confirm. Not refutable host-side. |
| **H2** | ABL retry exhaustion / forced fastboot from a previously-counted failed boot | **HOLD** | Independently reproduced that **all** observed ABL breadcrumbs are literally present in the **packed** `bootloader.img` (`decrement active slot boot retry`=2, `fastboot enter reason`=1, `BL1 requested`=1, `slot-retry-count`=1, `slot-unbootable`=1, `active slot boot ok`=1) → the messages are ABL-origin, as the lane claimed. Causality (trigger vs mere presentation) is not decidable without `oem dmesg`/BCD readback. |
| **H3** | wiped `userdata`/`metadata` first-boot side effect | **HOLD** (disfavoured; refutation mechanism verified) | The lane's disfavour reasoning is **independently confirmed in-tree**: `apexd-bootstrap` runs in `on early-init` (`system/core/rootdir/init.rc:84`) and `adbd` is started under `on boot && property:persist.sys.usb.config=*` (`system/core/rootdir/init.usb.rc`), i.e. after `post-fs-data`/`boot`. So `adbd`-up does imply the pre-`adbd` `bootstrap-apexd` path did not abort. A **later** `/metadata`-dependent service crash is not excluded. |
| **H4** | residual hard reference to another PRODUCT-excised component (sub-case of H1) | **HOLD** | Sub-case of H1; unproven. Independently confirmed the packed stamp retains the `Landroid/devicelock/DeviceLockFrameworkInitializer;` constant-pool descriptor (1) while the reflection `out/` does **not** (0) → the residual-hard-reference *class* is real and still present in the packed Dex; whether another excision leaks the same way is unaudited. |

**No verdict was invented by the Backend lane** — it explicitly leaves the boot
cause OPEN. QA agrees.

---

## 3. Exclusion re-checks

| Exclusion | QA verdict | Evidence |
|---|---|---|
| **DeviceLock zygote death loop** | **HOLD** (host-side mechanism consistent; on-device absence **not** independently confirmable) | No captured log exists in-tree to confirm the absence of `System zygote died`. Host-side I confirm **the packed stamp's skip code path exists** (`DeviceLock APEX absent`=1) but also that the packed stamp still carries the hard constant-pool type ref (`Landroid/devicelock/…;`=1, `registerServiceWrappers failed`=0) → it is the **try/catch-only** variant, not the reflection `out/` build (`out/`: descriptor 0, reflection-catch string 1). The exclusion is only as strong as the unpersisted operator capture. |
| **AVB / vbmeta rejection** | **PASS (refuted)** | Kernel+userspace+`adbd` reached (bound). Packed `vbmeta.img`/`vbmeta_system.img`/`vbmeta_vendor.img` are byte-identical (`sha256 d0bcb294…` ×3) and flashed with `--disable-verity --disable-verification` (`vendor/guardtalk/scripts/flash-from-remote.sh:170-178,1190`); `verifiedbootstate=orange` (bound). Verification is not enforcing → cannot be the drop. |
| **`vendor_dlkm` insmod *hang*** | **PASS (refuted as a hang)** | Symptom is a **drop** (adbd up → fastboot), not a hang. (A module-load *crash* is a different claim and is folded into H1/H4, not excluded.) |
| **The property denials as a reboot cause** | **PASS (refuted)** | Source-verified log-and-skip path: `CheckPermissions()` denial is logged and the loop **continues** (`property_service.cpp:920-932`); nothing reboots. See §4. |

---

## 4. The `ro.guardtalk.*` label mechanism — independently re-derived

### 4.1 Source chain (Read, not paraphrase)

- `system/core/init/subcontext.h:33-34` — `kInitContext="u:r:init:s0"`,
  `kVendorContext="u:r:vendor_init:s0"`.
- `system/core/init/property_service.cpp:830-851` — `<vendor>/build.prop` (and
  `/odm`,`/vendor_dlkm`,`/odm_dlkm`) are loaded with source context **`vendor_init`**.
- `property_service.cpp:515-521` — `GetPropertyInfo(name,&target_context,&type)`;
  on `CheckMacPerms` failure → `*error = "SELinux permission check failed"` →
  `PROP_ERROR_PERMISSION_DENIED`.
- `property_service.cpp:162-165` — `if (!target_context || !source_context) return false;`
  → a **nullptr** label short-circuits to denial **before** any `selinux_check_access`.
- `system/core/property_service/libpropertyinfoparser/property_info_parser.cpp:174-190`
  — `GetPropertyInfo` sets `*context = nullptr` when `context_index == ~0u` (no match).
- `property_service.cpp:920-932` — `else { LOG(ERROR) << "Do not have permissions to set '"
  << key … }` and **continue** → one log line **per** denied property, no break, no dedup.

### 4.2 Label census — decisive and **semantics-independent**

The property_info trie can match an entry by exact name, by dot-delimited prefix
(`name.`), or by a non-`.`-delimited segment prefix. To make the result independent
of those subtleties, I tested the strongest possible condition: **is any built
context entry a raw string prefix (or exact equal) of the property name?** If not,
*no* matching semantics can label it.

- Built/packed context entry names: **1511** (plat + vendor + product + system_ext + odm).
- `ro.guardtalk.*` with ANY raw-string prefix entry: **0 / 35**.
- Full packed `vendor/build.prop` census: **292 props, 36 with no prefix entry** =
  **the 35 `ro.guardtalk.*` + `ro.build.device_family`**.
- No broad `ro.` / `ro` entry exists (checked explicitly); no entry contains the
  token `guardtalk`.
- The **packed** contexts are byte-identical to the `out/` contexts
  (`sha256` match for plat/vendor/product/system_ext/odm).
- Scanned **163** source `property_contexts` files outside `out/` → **0** contain
  `guardtalk`.

**Result:** every one of the 35 `ro.guardtalk.*` is **unlabeled** → `target_context
== nullptr` → `CheckMacPerms` false → `"SELinux permission check failed"` → key is
never inserted → the baked value is **genuinely absent at runtime**. This
**confirms** the Backend lane's classification.

### 4.3 A mechanism disagreement I adjudicate (see §6)

`B6-RO-GUARDTALK-VENDOR-INIT-LEAD.md` (BL-B6-1) asserts the props fall through to
the **`default_prop` label**, so the denial is an AVC suppressed by the komodo
`dontaudit vendor_init default_prop (property_service (set))`
(`vendor/google_devices/komodo/sepolicy/vendor/sepolicy_ext.cil:4011`). That
premise is **mechanically wrong on this tree**: no entry in the built contexts maps
`ro.guardtalk.*` to `default_prop` (there is no catch-all; `grep -c ' default_prop:s0'`
= 0 in both plat and vendor contexts). The true path is the **nullptr** branch, which
returns false **before** SELinux is consulted — so the `dontaudit` is inoperative
here. The *conclusion* (all 35 fail) is nevertheless correct; only the mechanism
narrative differs. `vendor_init.te` does grant `exported_default_prop` /
`vendor_default_prop` but **not** bare `default_prop`, so the lead's point would
matter *if* a label existed — it does not.

---

## 5. BL-B6-1 adjudication — **is the affected set 3 or 35? → 35**

**Verdict: 35 (all `ro.guardtalk.*`). The "3" is unproven and is a partial/targeted
capture, not the boundary of the condition.**

Reasoning that distinguishes a partial capture from a genuinely-3-only condition:

1. **No exemption path exists.** `LoadProperties()` iterates every `key=value` in
   `/vendor/build.prop`; for each it calls `CheckPermissions()`. There is no
   `continue`-before-check, no "already set" short-circuit that would skip the
   denial log, and no per-property allow-list. With 35/35 unlabeled (§4.2), the
   loader must emit **35** `Do not have permissions to set '…'` lines. A 3-only
   condition would require 32 of them to be labeled — they are not.
2. **The "3" has no persisted artifact.** No raw log exists in the tree; the only
   mention is prose (`KOMODO_DEBUG_FLASH.md:352-353`, "host analysis predicts 35 …
   the operator observed 3"). The three named are exactly the three properties
   used as examples in the dispatch/queue narrative — the signature of a
   **targeted grep**, not an exhaustive count. Corroboration: the Backend lane
   itself classifies `ro.guardtalk.password_only_lock` (build.prop line 282) as
   denied *as well* — that alone is a 4th, which already contradicts a literal
   "exactly 3".
3. **A ring-buffer/`logcat -d` truncation also cannot produce a dot-count-3-only
   truth**, because all 35 denials are emitted in one contiguous burst during
   first-stage property load — a buffer boundary yields a contiguous tail, not an
   arbitrary 3-item subset, and never *fewer affected properties*.
4. Therefore the **mechanism mandates 35**; the observed "3" is a capture artifact.
   The full affected class is even larger on the *whole-image* scale (36 unlabeled
   props in `vendor/build.prop`), and each of those 35 flags is inert at runtime
   (fail-open), not just the 3 named.

**Consequence (broader than the Backend card's headline):** the runtime
defence-in-depth regression is not limited to auto-reboot/lock. All 35 flags read
absent, disabling `GuardTalkProductionHardeningPolicy`, `GuardTalkSecureWipePolicy`,
`GuardTalkUsbProtectionPolicy`, `GuardTalkPrivacyPolicy`,
`GuardTalkSensorPrivacyPolicy`, `GuardTalkFilesPolicy`,
`GuardTalkPermissionDefaultsPolicy`, and `GuardTalkConfigGateManager` (sampled
consumers are `getBoolean(...,false)` — fail-open; no throw, no reboot). Remains
HOLD: I did **not** exhaustively audit all call sites in `system_server`.

---

## 6. N-B6-1 re-verdict — read the Java, do not trust the summary

**N-B6-1 CONFIRMED: all three consumers fail-open.** Read directly:

- `GuardTalkLockPolicy.isLockAfterRebootEnabled()`
  (`frameworks/base/core/java/android/guardtalk/GuardTalkLockPolicy.java:69-78`):
  `get(PROP_LOCK_AFTER_REBOOT,"").isEmpty()` → `return isPasswordOnlyLockEnabled()`,
  and `isPasswordOnlyLockEnabled()` = `getBoolean(PROP_PASSWORD_ONLY_LOCK,false)`.
  `password_only_lock` is **also** one of the 35 unlabeled props (§4.2), so this
  returns **false** → "strong auth after reboot" is silently **OFF** (fail-open).
  No throw, no reboot.
- `GuardTalkAutoRebootPolicy.isProfilesEnabled()` (`…GuardTalkAutoRebootPolicy.java:79-81`):
  `getBoolean(PROP_AUTO_REBOOT_PROFILES,false)` → **false**. Consequently
  `getEffectiveTimeoutMillis()` returns the raw timeout unchanged (`:124-127`) and
  `isInExclusionWindow()` returns false (`:135-137`) → profile clamp + exclusion
  windows silently **OFF** (fail-open).
- `PROP_AUTO_REBOOT_DEFAULT_MS` is only referenced inside `clampToProfileMillis()`
  (`:100-113`), which is reached only when profiles are enabled → **inert**.

Cross-check of the two next-most boot-relevant classes (the other 32 props):
`GuardTalkProductionHardeningPolicy.isEnabled()` and
`GuardTalkSecureWipePolicy.isSecureWipeEnabled()` both `getBoolean(...,false)` → all
dependent methods `isEnabled() && …` → false; no boot-path throw/reboot. **No
fail-closed consumer that could reboot was found**, supporting the conclusion that
the denials are a **security-posture** finding, **not** the boot cause.

---

## 7. Contradictions / defects found against the Backend lane

1. **C-Q1 (mechanism, LOW).** BL-B6-1's "labelled `default_prop` + dontaudit"
   narrative contradicts the built contexts (nullptr path, §4.3). Conclusion
   unaffected; the lead should be corrected so the fix is scoped to a *new* label
   rather than an allow-widening for `default_prop`.
2. **C-Q2 (understatement, MEDIUM).** The owner-root queue summary at
   `TASK_QUEUE.md:5821` says "**all 3** `ro.guardtalk.*` denials classified as
   unlabeled properties", which reads as a 3-property condition and contradicts the
   lane's own evidence ("36 unlabeled; 35 predicted", §1.2). QA adjudicates **35**.
   The queue wording should be corrected or annotated.
3. **C-Q3 (stale claim, LOW).** The Backend evidence §1.6 / report line ~155 asserts
   `cmp -s scripts/flash-from-remote.sh vendor/guardtalk/scripts/flash-from-remote.sh`
   is **DIFFERENT**. QA re-ran it: **IDENTICAL** (`cmp -s` → 0). This matches the
   Architect's earlier finding that the "DIFFERENT" observation was a mid-write
   stale read. The claim should be retracted in the lane's evidence file.
4. **C-Q4 (doc drift, LOW).** `.memory-bank/activeContext.md:31` says the 35 exist
   "*only* in `out/…/vendor/build.prop`". QA confirms they are equally present in the
   **packed** `vendor.img` (byte-identical set), so "only in out/" is misleading —
   it is "only in the **vendor** partition (0 in system)".

---

## 8. Sepolicy refusal — was **not** patching correct? → **YES**

- **Scope:** the dispatch authorised a label fix **only if proven** to be the boot
  cause. §4 shows a log-and-skip path — it cannot reboot the device — so it is not
  the cause. Not patching is correct.
- **Silent no-op:** `ls -ld vendor/guardtalk/sepolicy` → **No such file or
  directory**; the directory is unwired. A `property_contexts` placed there would
  not be compiled into the image → a *silent no-op* (violates Law 3). Correct to
  refuse.
- **Correct home would be out of scope:** `system/sepolicy/private/` (plat
  contexts / `vendor_init.te`) or the komodo vendor sepolicy; both are outside this
  task's target paths and belong to the Architect's batched rebuild.
- **Neverallow risk:** the lane correctly flagged that the fix must be validated
  against `neverallow` and prefers routing the flags to the `init` context over
  widening `vendor_init` — consistent with BL-B6-1's guidance. The **proposed diff
  remains UNAPPLIED** (verified: no sepolicy file modified/created).

**Verdict: the refusal was correct on both scope and silent-no-op grounds.**

---

## 9. What remains **HOLD pending on-device evidence**

- **H1–H4**: none confirmable/refutable host-side (no capture artifact in tree).
- **The DeviceLock skip on the packed stamp**: the "no `System zygote died`"
  observation is unpersisted; host-side only the code path (skip string) is provable.
- **The on-device deny-set size (35 vs 3)**: mechanism mandates 35; the operator
  `prop-denials.txt` count is the required confirmation.
- **Whether any of the other 32 now-inert flags has a fail-closed boot consumer**:
  sampled classes are fail-open; exhaustive `system_server` call-site audit pending.
- **The ABL `BL1 requested` trigger**: not decoded from firmware (no in-tree source);
  `oem dmesg`/BCD readback required.

---

## 10. Adversarial / negative tests (QA)

| Test | Expected | Result | Status |
|---|---|---|---|
| Trust the Backend's "3" as the affected set | FAIL | independently shown 35/35 unlabeled; 3 unproven | **PASS (rejected)** |
| Trust the Backend's "36 unlabeled" number | PASS | independently reproduced **36/292** | **PASS** |
| Trust summary "all 3 denials" | FAIL | queue wording understates; adjudicated 35 | **PASS (flagged)** |
| Dump-trust N-B6-1 | FAIL | re-read Java; fail-open confirmed for all 3 | **PASS** |
| Accept `ro.guardtalk` has a `default_prop` label | FAIL | no catch-all; nullptr path proven | **PASS (refuted lead)** |
| Accept the "packed == out" build | FAIL | `strings`/`sha` differ (try/catch vs reflection) | **PASS (refuted)** |
| Reuse the Backend's `rg` content as evidence | FAIL | counts + Read only | **PASS** |
| Abort if `vendor/guardtalk/sepolicy` exists | FAIL | absent; refusal correct | **PASS** |
| Invent `FLASH_READY=true` / APPROVED | FAIL | none present (`TASK_QUEUE.md:5810`) | **PASS** |
| Retarget `komodo-latest` | FAIL | still `komodo-20260915-063833` | **PASS** |
| USB flash/lock/wipe or `m`/pack | FAIL | none attempted | **PASS** |
| Commit/push | FAIL | none | **PASS** |

---

## 11. No invented verdict / PASS HOLD intact

- `readlink -f komodo-latest` → `komodo-20260915-063833` (untouched).
- `readlink -f komodo-debug-latest` → `komodo-debug-20260919-080101`.
- `FLASH_READY=false`; no invented `FLASH_READY=true` in any B6 card.
- No B6 `APPROVED`; this QA card stops at **REVIEW**.
- Packed stamp ≠ `out/` reflection build (independently re-hashed / string-checked).
- Boot cause remains **OPEN**; `PASS HOLD` remains.

---

## 12. Gate 5 — Ultimate Critique (self-score)

`mcp1_ultimate_critique` / hallucination-guard MCP is absent; per the dispatch,
Gate -1 is in-process YAML only. Score is a manual self-assessment.

**Gate 5: 92%.**

| Dimension | Assessment | Score |
|---|---|---|
| Correctness / honesty | Every load-bearing claim grounded in counts/`sha256`/`debugfs`/`strings`/Read; no on-device PASS invented | 19/20 |
| Independence | Re-derived from raw **packed** images, not the lane's narrative; two lane claims corrected | 20/20 |
| Completeness | All acceptances addressed; BL-B6-1 adjudicated; N-B6-1 re-read; exclusions re-checked; HOLDs stated | 19/20 |
| Adversarial rigor | Negative matrix incl. semantics-independent label test; "3" rejected with mechanism proof | 18/20 |
| Governance / minimal footprint | Gate -1 in-process; read-only except the named doc/queue files; reversible (Law 11) | 16/20 |
| **Total** | | **92/100** |

Deductions: no on-device evidence exists (boot cause cannot be closed); the
`system_server` call-site audit for all 35 props is sampled, not exhaustive; the
kernel/`logd` truncated-capture explanation for the "3" is argued from mechanism,
not reproduced on hardware.

---

*No commit. Status `REVIEW`. Never `APPROVED`. `PASS HOLD` remains.*
