# AEGIS AUDIT RESULT — GuardTalkOS worktree (consolidated)

**Audit:** `/aegis-audit` — *continue the previous audit and give a result*
**Date:** 2026-09-25T10:07+04:00 · **Architect (Panel 1)** · Gate -1 **in-process**
**Owner root:** `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree` · `repository_id: grapheneos-worktree`
**Intensity:** **Extreme / full** — *continued at the established level rather than re-asking*, because the
operator said "continue the previous audit". (Deviation from `.windsurf/workflows/aegis-audit.md` Step 1's
mandatory intensity prompt, recorded so it is not a silent skip.)
**Authority:** `TASK_QUEUE.md` § `EXTREME AUDIT — AIRGAP CLAIM` + § `AUDIT WAVE DISPATCH`.

---

## 1. Headline result

> ### `DEC-EXCISE-AIRGAP-001` — the airgap claim is **FALSE**
> *"…every feature that makes the OS effectively airgapped is 100% removed on every Pixel model GuardTalk
> builds"* — **FALSE per service AND per device (all 13)**.
> Best waiver-generous reading: `TRUE-WITH-DORMANT-RESIDUALS`. **Never `TRUE`.**
> **36 residuals · 8 CRITICAL · 17-item operator waiver list.**

| Service | Verdict | Tier C (reachable) |
|---|---|---|
| Radio / cellular | **FALSE** | 9/13 + 4 hybrid; **0/13 Tier A** |
| Bluetooth | **FALSE** | 12–13/13 |
| Location / GNSS | **FALSE** | `shiba`, `husky` |
| Other / telemetry | **FALSE** | `appsearch` (13), `GuardTalkCheckin` (10) |
| Resolver / shared core | **HOLDS** | — (not a FAIL) |
| Gen 6 `gs101` / Gen 7 `gs201` | **AUDITED ABSENCE** | no build, no stamp, no advertise |

> ### Port audit wave — `A-PORT-WAVE-A` **CLEAN**; B/C carry the confirmed residuals
> `A-PORT-WAVE-A` 0C/0H/0M · `A-PORT-WAVE-B` 2 HIGH · `A-PORT-WAVE-C` **1 CRITICAL** ·
> `A-PORT-MATRIX-R2` 2 HIGH (incl. an **Architect claim that was unsubstantiated**).
> **Non-regression PASS on all four**; `rango-latest` unmoved.

---

## 2. Fresh re-verification (2026-09-25T10:07 — not cached)

Quiescent overnight: **no** new bundles, **no** product-file changes, **no** running build procs.

| Re-verified | Result |
|---|---|
| 13 × `-latest` targets | **unchanged** vs the audit's findings |
| `nitrous` blocklist on `frankel-latest` | **0 lines** — residual **holds** |
| `gpsd` in `shiba-latest/vendor.img` | **present** — residual **holds** |
| baseband `radio.img` in `out/` | **13 devices** — residual **holds** |
| `device/google/gs101*`/`gs201*` | **absent** — audited absence **holds** |
| `rango-latest` | `rango-20260802-130756` — **unmoved** |
| QA harness syntax (`bash -n`) | **87 scripts, 0 failures** |

**No finding is invalidated. No verdict changes.**

---

## 3. Audit inventory — 11 independent lanes, 93 findings

| Lane | Scope | Severity |
|---|---|---|
| `A-EXCISE-RADIO` | cellular, baseband FW, `radioExternal` | 2C/3H/5M/2L/1I |
| `A-EXCISE-BT` | userspace, APEX, GKI modules, `nitrous` | **1C**/2H/2M/2L/1I |
| `A-EXCISE-LOC` | GNSS HAL/daemon/VINTF/feature XML | 0C/2H/3M/3L/1I |
| `A-EXCISE-SURFACES` | NFC, UWB, telemetry, APEX-dormant set | 0C/2H/5M/3L |
| `A-EXCISE-13DEV-NONREGRESSION` | resolver / silent no-op | 0C/0H/0M/7L/2I — **RESOLVER HOLDS** |
| `A-EXCISE-AIRGAP-MATRIX` | umbrella + final verdict | **36 residuals / 8 CRITICAL** |
| `A-EXCISE-HONESTY` | claims audit | **2C**/5H/4M/3L/1I — 14 overstatements |
| `A-PORT-MATRIX-R2` | post-QA matrix re-audit | 0C/2H/3M/4L |
| `A-PORT-WAVE-A` | `caiman`,`comet`,`tegu`,`stallion` | **0C/0H/0M**/3L/4I — **CLEAN** |
| `A-PORT-WAVE-B` | `shiba`,`husky` | 0C/2H/0M/2L/3I |
| `A-PORT-WAVE-C` | `frankel`,`blazer`,`mustang` | **1C**/1H/2M/1L/1I |

**Aggregate (findings, excluding the umbrella's separate residual-severity axis):**
**6 CRITICAL · 19 HIGH · 24 MEDIUM · 30 LOW · 14 INFO = 93 findings.**

**QA verification (independent of the auditors):** `Q-EXCISE-LEDGER` — **falsified 16/130 ledger cells
(12.3%)**, all under-reporting reachability → the ledger is APPROVED but **not the tier authority**.
`Q-EXCISE-13DEV-MATRIX` — invariants hold 13/13. **Both harnesses proven non-vacuous (negative control
exits non-zero).**

---

## 4. The eight CRITICAL residuals (remediation backlog)

| # | Residual | Devices |
|---|---|---|
| R-1 | Baseband `radio.img`/`modem.img` shipped; `radio` **flashed** by `flash-from-remote.sh` | 13/13 |
| R-2 | Modem kernel transport `cpif`/`cpif_page`/`shm_ipc` **loaded** | 10/13 |
| R-3 | **8** BT/NFC GKI modules loaded, **0** blocklisted | 13/13 |
| R-4 | `nitrous.ko` (BCM4390 BT power/rfkill) loaded **unblocked** (factory `vendor_dlkm`) | 4 (`frankel`,`blazer`,`mustang`,`rango`) |
| R-5 | Shipped `stallion` README claims `no_radio` while `dmd.xml` re-declares telephony `oemservice` | 13/13 |
| R-6 | Init-started location daemon stack (`gpsd`/`lhd`/`scd`, `class main`, no `disabled`) | 2 (`shiba`,`husky`) |
| R-7 | `GuardTalkCheckin` telemetry client ships | 10/13 |
| R-8 | `DEVICE=mustang` flash **auto-resolves `mustang-latest`**, which carries **0** `nitrous` blocklist lines | `mustang` |

**Tier-C-by-design (must be *stated*, never called "removed"):** `appsearch` (13), `GuardTalkCheckin` (10),
WiFi/tethering/IPsec (13), sensors/camera/mic (13), userdebug (13).

**17-item operator waiver list** (Tier B): baseband firmware · framework telephony
(`telephony-common.jar` 13/13) · `radioExternal`/`oemservice` (6) · eUICC feature XMLs (12) · BT userspace
HAL (4 manifest `<name>` lines + 5 audio libs) · `nitrous` blocked (9) · GNSS kernel modules · APEX-dormant
set · telemetry/profiling stacks · `dmd.xml` runtime fragment · `dmd` daemon residue · SE/OMAPI/MIFARE
features · SELinux radio/GNSS labels · `FusedLocation` in stale stamps (4) · `devicelock` (3) · legacy
build vintage (4).

---

## 5. Falsification log — what each successful attack cost the claim

| Attack | Outcome | Cost |
|---|---|---|
| Is "dormant" really "removed"? | **succeeded** | kills the blanket green |
| Are the BT transport modules blocked? | **succeeded** (8 load, 0 blocked) | BT → Tier C, 13/13 |
| Is `nitrous` blocked? | **succeeded** (4 hybrids) | BT → Tier C |
| Do location daemons start? | **succeeded** (`class main`, no `disabled`) | Location → Tier C, 2/13 |
| Does the `no_radio` manifest hold? | **succeeded** (`dmd.xml` defeats it) | radio → Tier C |
| Does the ledger survive adversarial re-derivation? | **partially succeeded** (16/130) | ledger demoted from tier authority |
| Baseband inert without host stack? | **inconclusive** — no hardware | stays HOLD, **not** cleared |
| RIL binaries / HAL services genuinely gone? | **failed to falsify** | credited Tier A |
| Resolver silent no-op? | **failed to falsify** | **RESOLVER HOLDS** |
| Gen 6/7 leakage? | **failed to falsify** | audited absence confirmed |

---

## 6. Governance findings (the audit's own quality)

| ID | Finding |
|---|---|
| `E-22` | **An Architect approval note claimed a remediation that never happened.** `TASK_QUEUE.md:6387` said QA's `QA-W1`/`QA-W2`/`QI-1` were "accepted → docs corrected"; `PORT_MATRIX_GEN8910_PREFLIGHT.md` is **byte-identical** to QA's pre-remediation hash. |
| `E-23` | **Uncarded in-flight work.** `stage-laguna-release.sh` modified + a new diagnostic bundle appeared mid-audit; `T-LAGUNA-KLOG-DUMP` is **absent from the queue**. |
| `E-24` | **`stallion` builds with ZERO release flags in any channel** — a fourth, undocumented kernel-resolution mechanism; nothing guards it against silent change. |
| `E-18` | Architect wording corrected: hybrid `vendor.img` is **GuardTalkOS**, only `vendor_dlkm` is factory. |
| `E-12`/`E-14`/`E-17` | Three Architect measurement errors (shell false positive, repeated `readlink` bug, partition error) — **all caught by other lanes**, all corrected. |
| `DEC-ARCH-020` | `DONE_LOG.md` overwritten by a whole-file `Write`; **266 entries recovered** from transcripts; recovered block marked **evidence-bounded, not authoritative**. |
| — | **Protocol deviation:** `Q-EXCISE-13DEV-MATRIX` hand-edited the owner-root queue index (forbidden for subagents). |

**Meta-finding:** *every* measurement error in this program was caught by a **different lane** than the one
that made it. The adversarial/authoring separation is what produced the corrections and must be preserved.

---

## 7. Not proven / out of scope (explicit)

- **No on-device verification of anything.** No hardware attached. `LIVE_FLASH_CLAIMED=false`; DEC-009 HOLD.
  No `adb`/`fastboot` PASS was claimed anywhere. **Baseband inertness without the host stack is unproven.**
- **No signed-user production builds** — `T-PORT-<DEV>-KEYS` HOLD; no signing material in tree.
- **No boot-green claim for `rango`**; `rango-latest` unmoved.
- **Gen 6/7 not audited as products** — recorded only as an audited absence.
- **The remediation work has not been done.** All remediation cards are `BLOCKED`; `F-EXCISE-CLAIM-HONESTY`
  is `READY` but **undispatched**.

---

## 8. Operator decisions required (Law 0)

1. **`E-18` hybrid scope** — do `MODE=gtuserspace` hybrid `-latest` stamps count as "the built image"?
   (Verdict is FALSE either way; it gates the remediation batch's scope and touches `rango-latest`.)
2. **`GuardTalkCheckin`** — stay as a documented Tier-C-by-design exception, or be removed?
3. **The 17-item waiver list** — which Tier-B residuals are **waived** vs **remediated**?

---

## 9. Result statement

**The audit is complete and its result is unchanged and re-verified:**

- **The airgap claim is FALSE** on every service and every device; the best honest reading is
  `TRUE-WITH-DORMANT-RESIDUALS`, and only with explicit operator waivers.
- **The port builds are intact** — 13/13 stamped, `sha256sum -c` valid, zero regression to incumbents,
  resolver holds, no silent no-op — but **they are not excised**, which is a documentation and design
  problem, not a build problem.
- **11 lanes, 93 findings, 6 CRITICAL** at report level plus **36 residuals / 8 CRITICAL** on the umbrella
  register; both QA harnesses proven able to fail.
- **No product code was modified by any audit lane.** Every Architect error found was disclosed and
  corrected; none was concealed.
- **Nothing further can be proven without hardware.** The remaining risk is genuinely operational.
