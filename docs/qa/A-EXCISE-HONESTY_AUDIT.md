# A-EXCISE-HONESTY — Claims-Honesty Audit (Panel 5, Auditor)

| Field | Value |
|---|---|
| task_id | `A-EXCISE-HONESTY` |
| role | Auditor — Independent Deep Tech (Panel 5) |
| audit_scope | `code-review` |
| owner repository | `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree` (`repository_id: grapheneos-worktree`) |
| authoritative task path | `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree/TASK_QUEUE.md` §A3 `A-EXCISE-HONESTY`, pre-findings `E-1`..`E-18` |
| depends_on | `A-EXCISE-AIRGAP-MATRIX` ✅ REVIEW ACCEPTED |
| status | BLOCKED → **REVIEW** (this auditor never sets `APPROVED`) |
| **Gate -1** | **IN-PROCESS** — `.aegis/governance/laws/*.yaml` (24) + `.aegis/governance/gates/*.yaml` (11) loaded from disk and parsed. `governance_loaded=true`. No aegis-verifier / `ask_guardian` / `gate_enforcer` / Guardian HTTP call was made. |
| **Gate 5** | **HUMAN SKIP** — no numeric self-critique score is invented. |
| `LIVE_FLASH_CLAIMED` | **false** — no hardware, no USB/adb/fastboot. No device, boot, or runtime result is claimed. |
| Timestamp | 2026-09-24T17:09:00+04:00 |
| Write surface | This report + `.agent-comm/evidence/A-EXCISE-HONESTY/*` + one `.agent-comm/history/` event + `.agent-comm/signals/review-A-EXCISE-HONESTY.json`. **No** product/test/doc/doctrine/queue file edited. `.agent-comm/inbox/TO_ARCHITECT.md` was **NOT** touched; the derived queue was **NOT** hand-edited. |

---

## 0. What this audit is (and the standard)

The program's failure mode on this surface is a **lie, not a bug**: documentation and claims that
assert an airgap / removal posture the built artifacts do not support. This audit maps every such
statement to a **file:line**, quotes it, names the umbrella ledger cell that **contradicts** it, and
gives a one-line minimal wording fix.

The authority for "what the artifacts prove" is `A-EXCISE-AIRGAP-MATRIX` (REVIEW ACCEPTED) and the
reconciled 13 × service tier table (`umbrella §2`, §5). The operative kernel rule (umbrella §0):
a module listed in a shipped `modules.load` and not matched by `modules.blocklist` **loads at boot ⇒
Tier C**; Tier B (dormant) is **never** a removal and requires an explicit operator waiver.

**Scope audited:** `vendor/guardtalk/docs/EXCISION_MATRIX.md`, `vendor/guardtalk/README.md`,
`vendor/guardtalk/docs/PORT_MATRIX_GEN8910_PREFLIGHT.md`, `vendor/guardtalk/docs/WEB_INSTALLER_CHANNEL.md`,
`vendor/guardtalk/docs/FLASH.md`, the web-installer claim surface (`web-installer/**`), the
`feature-excised/*.mk` in-file claim comments (`E-16`, `bt-excised.mk`, `nfc-excised.mk`,
`loc-excised.mk`), the `releases/desktop-flash/*/README-FLASH-DESKTOP.md` honesty blocks, and any
other doc using airgap / air-gapped / radio-free / 100% / removed / excised language.

---

## 1. Severity counts

| Severity | Count | IDs |
|---|---:|---|
| **CRITICAL** | **2** | F-1, F-2 |
| **HIGH** | **5** | F-3, F-4, F-5, F-6, F-7 |
| **MEDIUM** | **4** | M-1, M-2, M-3, M-4 |
| **LOW** | **3** | M-5, M-6, M-7 |
| **INFO** | **1** | the airgap-string ruling (§4) |
| **Total overstatements** | **14** | |

Split by the requested taxonomy: **(a) outright false = 7** (F-1..F-7) · **(b) technically-true-but-misleading
= 7** (M-1..M-7) · **(c) correct claims verified = 5** (C-1..C-5, §3).

---

## 2. (a) Outright false claims

### F-1 — CRITICAL — `guardtalk-feature-excised.mk:130-139`: the BCP-excised APEX "is gone"

> `vendor/guardtalk/feature-excised/guardtalk-feature-excised.mk:133`
> `# healthfitness, ondevicepersonalization) are now FULLY excised, not just`
> `vendor/guardtalk/feature-excised/guardtalk-feature-excised.mk:138`
> `# now defence-in-depth (the APEX itself is gone). See apex-bcp-excised.mk`

**Contradicting cells.** `apex-bcp-excised.mk:55` — "# BOOT-LOOP INCIDENT (2026-07-04, tokay userdebug) —
BCP excision **DISABLED**", with all three filter stages marked `[DISABLED]` at `:81`, `:91`, `:101`.
Umbrella §5 `apex_dormant_set` / "APEX is gone" → **B**, "claim-integrity defect", "Artifacts present
13/13"; §8.1 A-12 ("Find an APEX the makefile says 'is gone'"); H-X2. Pre-finding **`E-16`** (`TASK_QUEUE.md:6995`).

**Minimal fix.** Replace "are now FULLY excised … the APEX itself is gone" with "are **feature-gated
dormant** (BCP excision **DISABLED** 2026-07-04, see `apex-bcp-excised.mk`) — Tier B; the APEX is
**present on 13/13**".

### F-2 — CRITICAL — `bt-excised.mk:19-20` (and `:170-172`): GKI BT modules "harmless without nitrous"

> `vendor/guardtalk/feature-excised/bt-excised.mk:19-20`
> `# bluetooth.ko / hci_uart.ko / btbcm.ko remain in system_dlkm but are harmless`
> `# without nitrous (no rfkill power-on, no HCI transport).`

**Contradicting cell.** Umbrella §1.1/§2 `bluetooth_gki_modules` = **C 13/13** — **8** BT/NFC GKI
modules (`hci_uart`, `btsdio`, `btbcm`, `btqca`, `bluetooth`, `rfcomm`, `hidp`, `nfc`) are in
`system_dlkm/modules.load` with **0** blocklisted, so they **load at boot**; `nitrous_module` itself is
**C on 4/13** laguna hybrids. Umbrella C-B1, §8.1 A-6. Pre-finding **`E-14`**.

**Minimal fix.** "…remain **and load unblocklisted** (Tier C). The 'harmless without nitrous'
invariant is **not supported**; extend the `system_dlkm` blocklist (`T-EXCISE-GKI-BT-MODULES`)."

### F-3 — HIGH — `bt-excised.mk:131-132`: dropping the HAL package "removes the HAL declaration"

> `vendor/guardtalk/feature-excised/bt-excised.mk:131-132`
> `# package. Dropping that package (Layer 1 above) removes the HAL declaration`
> `# so libvintf compatibility checks no longer expect a Bluetooth HAL to be`

**Contradicting cell.** Umbrella **D4** / §1.1 / H-B1 — the shipped vendor VINTF manifest declares
`android.hardware.bluetooth` (IBluetoothHci/default), `bluetooth.finder`, `bluetooth.ranging`, and
`vendor.google.bluetooth_ext` on **13/13** (`tokay` not an exception); `vendor_manifest_no_bt.xml`
exists but is unwired. Layer 1 drops the **HAL package**, not the declarations.

**Minimal fix.** Add: "Layer 1 drops the HAL **package**; **4 BT HAL declarations remain in the shipped
vendor VINTF manifest on 13/13** (`vendor_manifest_no_bt.xml` unwired) — H-B1."

### F-4 — HIGH — `README.md:7`: "cellular stack removed (CPIF, modem firmware, RIL)"

> `vendor/guardtalk/README.md:7`
> `- **Profile:** `tokay-cur-user` with cellular stack removed (CPIF, modem firmware, RIL).`

**Contradicting cell.** Umbrella §2 `baseband_firmware` = **B 13/13** — `radio.img`/`modem.img` ship in
every built image and every stamp, and the flasher **writes the `radio` partition** (H-R1; umbrella §1.1
"baseband firmware shipped **and flashed** on 13/13 (Tier B, no waiver)"). Pre-finding **`E-1`**. (The
CPIF/RIL halves are defensible for `tokay`, which is Tier A on the modem transport — but "modem
firmware removed" is false.)

**Minimal fix.** "host RIL/telephony excised; **baseband firmware (`radio.img`) still ships and is
flashed** (Tier B residual — H-R1)."

### F-5 — HIGH — `branding/signing-keys/RUNBOOK.md:25`: "BT is excised from GuardTalkOS anyway"

> `vendor/guardtalk/branding/signing-keys/RUNBOOK.md:25`
> `- **No Bluetooth** (BT is excised from GuardTalkOS anyway; the signing`

**Contradicting cell.** Umbrella Bluetooth = **FALSE**: 8 BT/NFC GKI modules load unblocklisted on
**13/13** (C-B1); 4 BT HALs declared on 13/13 (D4); BT userspace HAL Tier B without waiver.

**Minimal fix.** "the signing host must keep BT off regardless; **GuardTalkOS BT excision is not
complete** (see `A-EXCISE-BT`)."

### F-6 — HIGH — `OEM_DEVICE_SPECIFICATION.md:19,34,38`: "WiFi-only product with no cellular"

> `vendor/guardtalk/docs/OEM_DEVICE_SPECIFICATION.md:19-20`
> `Android Ready SE Alliance program, adapted for a **WiFi-only product with no cellular modem**.`
> `:34` `| Radios present | WiFi 6E/7 only. Bluetooth/NFC/GNSS optional (software-excised in current builds) |`
> `:38` `**WiFi-only is a cost and security advantage for the OEM:** removing the modem eliminates`

**Contradicting cell.** Umbrella §1.1/§2: radio/cellular **FALSE** (`baseband_firmware` B 13/13;
`cellular_modem_kernel_transport` C 10/13); Bluetooth **FALSE** (C 13/13); Location/GNSS **FALSE**
(`location_gnss_kernel` C 11/13; `location_gnss_userspace` C 2/13). The `:34` parenthetical
"software-excised in **current builds**" is the artifact-facing assertion — it is not supported.

**Minimal fix.** Mark the spec as target-OEM requirements (not current builds) and, if current-build
language is kept, state the residuals: baseband firmware ships; BT/GNSS kernel modules load.

### F-7 — HIGH — `loc-excised.mk:1-3,269-270,180`:GNSS "daemons never start"

> `vendor/guardtalk/feature-excised/loc-excised.mk:269-270`
> `#     copy-files filter above), init never loads the gnssd or`
> `#     slsi_gnss_service definitions and the daemons never start.`
> header `:1` `# T-W2-I5-LOC / T-LOC-FULL — 5-layer graceful excision of the GPS/GNSS HAL`

**Contradicting cell.** Umbrella §2/§5 `location_gnss_userspace` = **C on `shiba`/`husky`** — the shipped
`init.gps.rc` declares `gpsd`, `lhd`, `scd` in **`class main` with no `disabled`**, so init starts them;
`gps.default.so` (269,656 B) and `/etc/gnss/*` are present. **D3** (Architect upheld); C-L1; §8.1 A-10.
Pre-finding **`E-9`**. Root cause: `loc-excised.mk` filters only `gnss`-prefixed names
(`:151`, `:157`) while the `zuma_shusky` trees ship `gps`/`lhd`/`scd` names — so the blanket
"the daemons never start" is false on 2/13, and `:180` "no consumer once the HAL is gone" is likewise
false there (`/etc/gnss/*` is consumed by the boot-started daemons).

**Minimal fix.** Extend the name set to `gpsd`,`lhd`,`scd`,`gps.default.so`,`init.gps.rc`,`/etc/gnss/*`
for `zuma_shusky` (`T-EXCISE-LOC-GPS-NAME-COVERAGE`), or qualify the blanket claim to the two
`gnssd`/`slsi_gnss_service` definitions actually filtered.

---

## 3. (b) Technically-true-but-misleading

### M-1 — MEDIUM — `EXCISION_MATRIX.md:288-291`: `androidboot.radio.disabled=1` "unchanged"

> `vendor/guardtalk/docs/EXCISION_MATRIX.md:289`
> `` `androidboot.radio.disabled=1`, and the fingerprint drop set (13/13 tokens). No ``

The §6 zero-regression statement lists the in-force devices `tokay`, `akita`, `komodo`, **`rango`** and
claims the radio-disable cmdline is unchanged. That is true **at source**, but the **shipped** artifact
tell is different: umbrella **D2** — `androidboot.radio.disabled` is **ABSENT on 4/13**, including
`rango-latest` (`rango-20260802-130756`). M-R3.
**Fix.** "Source-level invariant only — the shipped laguna stamps lack the flag (re-stamp, M-R3)."

### M-2 — MEDIUM — stamp READMEs "Radio is excised"

> `releases/desktop-flash/caiman-latest/README-FLASH-DESKTOP.md:74-75`
> `- Radio is excised (`GUARDTALK_RADIO_EXCISED=true`, `modem` stripped from`
> `  `AB_OTA_PARTITIONS`). `radio.img` ships for partition-layout parity, same as`

Occurs in 15 stamp READMEs (the honesty-block set: `shiba`, `shiba-latest`, `husky`, `husky-latest`,
`stallion`, `stallion-latest`, `tegu`, `tegu-latest`, `comet`, `comet-latest`, `caiman-20260922-090535`,
`caiman-latest`, `frankel-20260922-165726`, `blazer-20260923-034646`, `mustang-20260923-101119`). The
parenthetical is narrowly scoped to `AB_OTA_PARTITIONS`, but the **headline** "Radio is excised" is
contradicted by umbrella radio = **FALSE** (baseband B 13/13; `cpif` C 10/13). The same READMEs are
otherwise scrupulous (FLASH_READY=false, LIVE_FLASH_CLAIMED=false, no boot claim).
**Fix.** "**Host** RIL/telephony excised; `modem` removed from `AB_OTA_PARTITIONS`; **baseband `radio.img`
still ships and is flashed**."

### M-3 — MEDIUM — hybrid stamp READMEs: internal vendor contradiction (E-18 check)

> `releases/desktop-flash/frankel-20260923-094457/README-FLASH-DESKTOP.md:17`
> `` | `vendor` / vendor_dlkm / system_dlkm | Factory `BP4A.260205.001` | ``
> `:47` `Factory BP4A.260205.001 **boot + dlkm** + GuardTalkOS **system/system_ext/product/vendor** (same OUT). MODE=gtuserspace.`
> `:61` `- vendor: GT vendor.img (GuardTalkOS OUT)`
> `:86` `| vendor | GuardTalkOS OUT |`

**E-18 result (independent re-derivation — see evidence `hybrid-vendor-hashes.txt`).** The dispatch
premise "the 4 laguna hybrids carry **factory `vendor`**" is imprecise: the hybrid **`vendor.img`
equals the full-GuardTalk `vendor.img`** (`frankel` `de9233a2…` == fullgt, ≠ factory `bb8f3462…`;
`blazer` `c357e1e4…` == fullgt, ≠ factory `426ec4cd…`), i.e. `vendor` **is** GuardTalkOS. What **is**
factory is **`vendor_dlkm`/`system_dlkm`** (`blazer` hybrid `vendor_dlkm` `28333477…` == factory;
`frankel` hybrid ≠ fullgt `9a1543e6…`) — which is exactly the operative E-18 mechanism and it **holds**.

**Conclusion on the E-18 question ("do any docs imply the hybrids are fully-excised GuardTalk builds?"):**
No. Each hybrid README **discloses** "hybrid bring-up (`MODE=gtuserspace`): factory boot chain + dlkm,
GuardTalkOS logicals … **NOT boot-verified**", and none carries a "Radio is excised" bullet. The only
defect is the **internal contradiction**: line `:17` groups `vendor` under "Factory" while `:47`/`:61`/`:86`
(and the artifact) say GuardTalkOS. That mis-grouping **understates** GuardTalk content — it is not an
airgap overstatement, but it is a claim-integrity defect worth correcting (a reader who trusts `:17`
would wrongly conclude the vendor-side excisions do not apply).
**Fix.** Remove `vendor` from the "Factory" row at `:17` (leave `vendor_dlkm / system_dlkm`), so the
README matches `:47`/`:61`/`:86` and the artifact.

### M-4 — MEDIUM — `EXCISION_LEDGER.md:134`: "the built vendor `manifest.xml` … radio-free"

> `vendor/guardtalk/docs/EXCISION_LEDGER.md:134`
> `entries on all 13 devices, and the built vendor `manifest.xml` provenance is the radio-free`

True for the **main** manifest file, but a reader infers **runtime** radio-free, which is contradicted by
umbrella **H-R2** / §8.1 A-2 / RADIO F-003: a runtime `dmd.xml` VINTF fragment re-declares a telephony
`oemservice` HAL on **13/13**.
**Fix.** "…**main** manifest only; a `dmd.xml` fragment re-declares a telephony HAL at runtime — H-R2."

### M-5 — LOW — `remove-packages.mk:4`: IMS/IWLAN/CarrierConfig2 "have no transport"

> `vendor/guardtalk/radio-excised/remove-packages.mk:4`
> `# stack excised above, IMS, IWLAN, and CarrierConfig2 have no transport and`

The userspace radio-HAL transport is gone, but the **kernel modem transport** `cpif`/`cpif_page`/`shm_ipc`
ships in `modules.load` on **10/13** (umbrella C-R1).
**Fix.** "no **userspace radio-HAL** transport; the kernel modem transport still loads on 10/13 (C-R1)."

### M-6 — LOW — `ATTACK_SURFACE_REPORT.md:407`: FusedLocation "intentionally KEPT"

> `vendor/guardtalk/docs/ATTACK_SURFACE_REPORT.md:407`
> `| 12 | **FusedLocation** | /system/app | loc-excised.mk:42–49 intentionally KEPT ...`

Now stale: `loc-excised.mk:141` drops `FusedLocation` by exact name and `:210-212` filters it out of
`PRODUCT_SYSTEM_SERVER_APPS`. Umbrella M-L1 notes FusedLocation survives only in the 4 stale stamps.
**Fix.** "now dropped by `loc-excised.mk` (exact name); present only in the 4 stale stamps (M-L1)."

### M-7 — LOW — `SEIZURE_CHECKIN.md:54-55`: "nothing leaves the device"

> `vendor/guardtalk/docs/SEIZURE_CHECKIN.md:54-55`
> `device. Onion URL without SOCKS → `skipped_no_tor`, nothing leaves the device.`

The statement is correctly **conditional** (empty endpoint / missing SOCKS), and the doc is explicit that
it ships an outbound client. But the outbound `GuardTalkCheckin` client **is present on 10/13** and does
send when an endpoint is provisioned (umbrella C-S1 / `telemetry_checkin` = **C\*** 10/13). A headline
reader can misread "nothing leaves the device" as "no telemetry egress."
**Fix.** Keep the conditionals; add "the client ships on 10/13 and does send when an endpoint is provisioned."

---

## 4. Airgap-string ruling (web-installer surface) — CONFIRM the Architect's recon

**Question:** does any **OS-level** airgap claim exist on the web-installer surface?

**Ruling: NO. The Architect's recon is CONFIRMED.** The only two `air-gapped` strings are
**installer-/signing-host** claims:

- `vendor/guardtalk/web-installer/routes/install/early-steps.ts:217` — `"Your signing machine must stay air-gapped"` → referent = the **offline key-signing machine**.
- `vendor/guardtalk/web-installer/test/claims.test.ts:39` — `"The installer runs air-gapped; nothing leaves the tab."` → referent = the **browser-tab installer** (allowed fixture in the `security-word-requires-mechanism` lint test).
- Generated copies of the same string: `web-installer/dist/site/install/early-steps.js:169`, `web-installer/dist/routes-js/routes/install/early-steps.js:169` (not separate claims).

A negative search of the entire surface (`--include=*.ts,*.tsx,*.js,*.md`, excluding `node_modules`) found
**zero** occurrences of `radio-free`, `100% removed`, `excised`, or any OS telemetry/radio/BT/GNSS removal
claim; the only `radio`/`bluetooth` hits are **flash-order / partition** references
(`bootloader/radio/boot/…`) and unrelated identifiers (`rollbackIndexLocation`, `location.search`). Raw
evidence: `.agent-comm/evidence/A-EXCISE-HONESTY/airgap-strings-webinstaller.txt`.

---

## 5. (c) Correct claims verified (not just hunted)

| ID | Claim | Cell confirming it |
|---|---|---|
| **C-1** | `nfc-excised.mk:17-27,131-138` — mainline NFC stack dormant; dropping the package removes the NFC HAL declaration | umbrella `nfc_userspace_hal` = **A 13/13** ✔ (kernel `nfc.ko` loads 13/13, but that is outside this file's claimed scope) |
| **C-2** | `apex-bcp-excised.mk:52-78` — honest 2026-07-04 `BCP excision DISABLED` disclosure | matches umbrella H-X2 / `E-16` ✔ |
| **C-3** | `WEB_INSTALLER_CHANNEL.md` — `verifiedBootClaim: none`, "do not advertise this as a locked GrapheneOS install", rango not boot-green | no removal/airgap claim present ✔ |
| **C-4** | `early-steps.ts:217` + `claims.test.ts:39` — the two `air-gapped` strings | installer-/signing-host only; no OS-level claim ✔ |
| **C-5** | `bt-excised.mk` Layers 1/2/4 (userspace package / feature-XML / init-rc excision) | umbrella §8.2 B-5: 0/13 BT HAL service binaries ✔ (only Layers 3 & 5 are false — F-2/F-3) |

Also verified **clean** (no overstatement found beyond the notes above): `PORT_MATRIX_GEN8910_PREFLIGHT.md`
(a prerequisites doc with explicit non-claims), `FLASH.md` (tokay-scoped operator notes; no airgap claim),
`WEB_INSTALLER_CHANNEL.md`, and `EXCISION_MATRIX.md` §1–§5 (resolver mechanics).

---

## 6. Consolidated overstatement table (file:line → contradicting cell → fix)

| # | Sev | Cat | file:line | Contradicting cell | Minimal fix |
|---|-----|-----|-----------|--------------------|-------------|
| F-1 | CRIT | a | `feature-excised/guardtalk-feature-excised.mk:133,138` | §5 `apex_dormant_set` B 13/13; H-X2; `E-16` | "feature-gated dormant (BCP DISABLED 2026-07-04); APEX present 13/13" |
| F-2 | CRIT | a | `feature-excised/bt-excised.mk:19-20,170-172` | `bluetooth_gki_modules` C 13/13; C-B1; `E-14` | "…load unblocklisted (Tier C); 'harmless without nitrous' unsupported" |
| F-3 | HIGH | a | `feature-excised/bt-excised.mk:131-132` | D4: 4 BT HALs declared 13/13; H-B1 | "package dropped, declarations remain 13/13" |
| F-4 | HIGH | a | `README.md:7` | `baseband_firmware` B 13/13; H-R1; `E-1` | "baseband `radio.img` still ships and is flashed" |
| F-5 | HIGH | a | `branding/signing-keys/RUNBOOK.md:25` | BT = FALSE (C 13/13) | "BT excision is not complete" |
| F-6 | HIGH | a | `docs/OEM_DEVICE_SPECIFICATION.md:19,34,38` | radio/BT/LOC = FALSE | mark as target-spec; state residuals |
| F-7 | HIGH | a | `feature-excised/loc-excised.mk:1-3,269-270,180` | `location_gnss_userspace` C on shiba/husky; C-L1; D3; `E-9` | extend name set to gpsd/lhd/scd; or qualify |
| M-1 | MED | b | `docs/EXCISION_MATRIX.md:289` | D2: absent 4/13 (incl. rango); M-R3 | "source invariant only; laguna stamps lack it" |
| M-2 | MED | b | `releases/desktop-flash/<15 stamps>/README-FLASH-DESKTOP.md` (e.g. `caiman-latest:74`) | radio = FALSE; baseband B 13/13 | "host RIL excised; baseband ships/flashed" |
| M-3 | MED | b | hybrid READMEs `…-094457/-090842/-094541:17` | artifact: vendor == fullgt ≠ factory; dlkm == factory | drop `vendor` from the "Factory" row at `:17` |
| M-4 | MED | b | `docs/EXCISION_LEDGER.md:134` | H-R2: runtime `dmd.xml` fragment 13/13 | "main manifest only; fragment defeats it" |
| M-5 | LOW | b | `radio-excised/remove-packages.mk:4` | C-R1: `cpif` C 10/13 | "no userspace HAL transport; kernel transport loads" |
| M-6 | LOW | b | `docs/ATTACK_SURFACE_REPORT.md:407` | `loc-excised.mk:141,210-212`; M-L1 | "now dropped; only in 4 stale stamps" |
| M-7 | LOW | b | `docs/SEIZURE_CHECKIN.md:54-55` | `telemetry_checkin` C* 10/13; C-S1 | "client present 10/13; sends when provisioned" |

---

## 7. Falsification log (attacks attempted on this audit)

| # | Attack | Result |
|---|---|---|
| H-1 | Find an OS-level airgap claim on the web-installer surface | **FAILED** — only the two installer-host strings; recon confirmed. |
| H-2 | Test the E-18 premise that hybrid `vendor` is factory | **PARTIAL** — hybrid `vendor.img` is GuardTalkOS (== fullgt ≠ factory); `vendor_dlkm`/`system_dlkm` **are** factory. E-18 mechanism holds; premise imprecise on `vendor`. |
| H-3 | Find a hybrid README claiming full excision | **FAILED** — all disclose hybrid + factory dlkm + NOT boot-verified; only an internal `:17` mis-grouping (M-3). |
| H-4 | Find a doc claiming "100% removed"/"radio-free" at OS level | Found `README.md:7` (F-4), `OEM_DEVICE_SPECIFICATION.md:34` (F-6), and the stamp "Radio is excised" bullets (M-2); the umbrella docs themselves are honest (they adjudicate FALSE). |
| H-5 | Check that `nfc-excised.mk`'s removal claim is true | **CONFIRMED TRUE** (userspace Tier A) — recorded as C-1, per the "not just hunted" requirement. |

**Claimed/not-claimed:** `LIVE_FLASH_CLAIMED=false`; `FLASH_READY=false`; `BOOT_VERIFIED=false`. No device,
boot, or runtime result is claimed for any device. No USB/adb/fastboot. No Gate 5 score invented.

---

## 8. Evidence index

All under `.agent-comm/evidence/A-EXCISE-HONESTY/`:

| File | Contents |
|---|---|
| `overstatement-map.tsv` | The full mapped table (ID · category · severity · file:line · quote · contradicting cell · fix). |
| `claim-line-index.txt` | Verbatim claim:line index with the contradicting umbrella cell per finding. |
| `airgap-strings-webinstaller.txt` | The two `airgap` strings + the negative full-surface search (raw). |
| `hybrid-vendor-hashes.txt` | E-18 re-derivation: sha256 of hybrid vs fullgt vs factory `vendor.img`/`vendor_dlkm.img`. |
| `severity-counts.json` | Machine-readable counts + ID→severity/category map + airgap ruling. |

**Primary sources re-read:** `vendor/guardtalk/docs/qa/A-EXCISE-AIRGAP-MATRIX_AUDIT.md`;
`TASK_QUEUE.md` §A2 (`E-1`..`E-18`, lines 6980–6998) / §A3; `vendor/guardtalk/feature-excised/{guardtalk-feature-excised,apex-bcp-excised,bt-excised,nfc-excised,loc-excised}.mk`;
`vendor/guardtalk/README.md`; `docs/{EXCISION_MATRIX,PORT_MATRIX_GEN8910_PREFLIGHT,WEB_INSTALLER_CHANNEL,FLASH,EXCISION_LEDGER,ATTACK_SURFACE_REPORT,SEIZURE_CHECKIN,OEM_DEVICE_SPECIFICATION}.md`;
`branding/signing-keys/RUNBOOK.md`; `radio-excised/remove-packages.mk`; `web-installer/**`;
`releases/desktop-flash/*/README-FLASH-DESKTOP.md`.

---

## 9. Honesty holds

- `Gate -1`: in-process; `governance_loaded=true`. No aegis-verifier / `ask_guardian` / `gate_enforcer` / Guardian HTTP.
- `Gate 5: HUMAN SKIP` — no score invented.
- Read-only over product/test/doc/doctrine/queue: **no** `.mk/.sh/.py/.ts/.tsx/.js/.jsx/.css` product or test file,
  no `doctrine/`, `governance/{laws,gates}/`, `.env`, credentials, `.git`, `keys/` touched. No task status changed.
  No agent dispatched. `.agent-comm/inbox/TO_ARCHITECT.md` was **NOT** modified; `.agent-comm/TASK_QUEUE.md` was **NOT**
  hand-edited.
- Status reported to the Architect as **REVIEW**; **never `APPROVED`**.

*Auditor: AEGIS Independent Deep Tech Auditor (Panel 5) · task `A-EXCISE-HONESTY` · read-only · **REVIEW** · `Gate 5: HUMAN SKIP` · `LIVE_FLASH_CLAIMED=false` · never APPROVED.*
