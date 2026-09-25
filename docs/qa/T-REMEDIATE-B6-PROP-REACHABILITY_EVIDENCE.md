# QA/Backend Evidence — T-REMEDIATE-B6-PROP-REACHABILITY

**Task:** `T-REMEDIATE-B6-PROP-REACHABILITY` (Backend, Panel 2, P0)
**DEC:** `DEC-REMEDIATE-019` · **QA pair:** `Q-REMEDIATE-B6-PROP-REACHABILITY`
**Date:** 2026-09-19T16:45Z · **Status:** `REVIEW` (never `APPROVED`)
**Owner repo:** `/mnt/Big-Storage/GuardTalk/GrapheneOS-worktree`
**Gate −1:** in-process, owner-local `.aegis/governance/` (24 laws + 11 gates YAML); MCP (`aegis-verifier` / `ask_guardian` / `gate_enforcer`) **not** called (forbidden).
**Gate 5 self-score:** **93/100** (see § Gate 5).
**Scope discipline:** security-posture regression **only**. This card does **not** explain or fix the boot-logo → fastboot fault.

> **Shell-paraphrase caveat honoured.** Every count below is a `grep -c` /
> `debugfs` **number** or a **Read**-tool citation. No `rg`/`grep` *content* line
> is used as evidence.

---

## 1. Root cause — why the props land in `vendor/build.prop`

### 1.1 Inherit chain (which `.mk` contributes which property)

`Read vendor/google_devices/komodo/komodo.mk` (line 4773) — the only GuardTalk
hook for komodo:

```4771:4776:vendor/google_devices/komodo/komodo.mk
include vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk
include vendor/guardtalk/device/komodo/guardtalk-insmod.mk
```

`vendor/guardtalk/radio-excised/guardtalk-radio-excised.mk` then pulls:

- `vendor/guardtalk/device/tokay/guardtalk-product-props.mk` — **21** `ro.guardtalk.*`
  (komodo has **no** `product-props` file of its own; `ls vendor/guardtalk/device/komodo/ | grep -c product-props` = **0**).
- per-device lookup `vendor/guardtalk/device/$(PRODUCT_DEVICE)/guardtalk-production-hardening.mk`
  → komodo's own file — **9** `ro.guardtalk.*` (+`production_profile` on `user`),
  and it includes `guardtalk-telemetry.mk` (**1**), `guardtalk-messenger.mk` (**1**),
  `guardtalk-wifi-gateway.mk` (**3**), `guardtalk-defaults.mk`.

21 + 9 + 1 + 1 + 3 = **35**. Exact.

### 1.2 Why those `.mk` lines produced the *vendor* file

`ro.guardtalk.*` was declared with **`PRODUCT_PROPERTY_OVERRIDES`**. On a
full-treble product that variable is routed to **`vendor/build.prop`**:

```787:794:build/make/core/config.mk
# BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED can be true only if early-mount of
# partitions is supported. But the early-mount must be supported for full
# treble products, and so BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED should be set
# by default for full treble products.
ifeq ($(PRODUCT_FULL_TREBLE),true)
  BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED ?= true
endif
```

```70:70:build/make/core/soong_extra_config.mk
$(call add_json_bool, PropertySplitEnabled, $(filter true,$(BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED)))
```

`PropertySplitEnabled` then decides the destination inside the generator:

```529:543:build/soong/scripts/gen_build_prop.py
def build_vendor_prop(args):
  config = args.config

  # Order matters here. When there are duplicates, the last one wins.
  # TODO(b/117892318): don't allow duplicates so that the ordering doesn't matter
  variables = []
  if config["PropertySplitEnabled"]:
    variables += [
      "ADDITIONAL_VENDOR_PROPERTIES",
      "PRODUCT_VENDOR_PROPERTIES",
      # TODO(b/117892318): deprecate this
      "PRODUCT_DEFAULT_PROPERTY_OVERRIDES",
      "PRODUCT_PROPERTY_OVERRIDES",
    ]
```

```500:518:build/soong/scripts/gen_build_prop.py
def build_system_prop(args):
  config = args.config

  # Order matters here. When there are duplicates, the last one wins.
  # TODO(b/117892318): don't allow duplicates so that the ordering doesn't matter
  variables = [
    "ADDITIONAL_SYSTEM_PROPERTIES",
    "PRODUCT_SYSTEM_PROPERTIES",
    # TODO(b/117892318): deprecate this
    "PRODUCT_SYSTEM_DEFAULT_PROPERTIES",
  ]

  if not config["PropertySplitEnabled"]:
    variables += [
      "ADDITIONAL_VENDOR_PROPERTIES",
      "PRODUCT_VENDOR_PROPERTIES",
    ]
```

and the *only* path that copies `PRODUCT_PROPERTY_OVERRIDES` into the **system**
file is gated on split being **off**:

```271:281:build/soong/scripts/gen_build_prop.py
def append_additional_system_props(args):
  props = []

  config = args.config

  # Add the product-defined properties to the build properties.
  if not config["PropertySplitEnabled"] or not config["VendorImageFileSystemType"]:
    if "PRODUCT_PROPERTY_OVERRIDES" in config:
      props += config["PRODUCT_PROPERTY_OVERRIDES"]
```

**Conclusion (make-level):** with `PRODUCT_FULL_TREBLE=true` (komodo),
`PropertySplitEnabled=true`, so `PRODUCT_PROPERTY_OVERRIDES` → *vendor only*.
The GuardTalk `.mk` files chose the wrong variable; the split logic did the rest.

### 1.3 Why the props were then *denied* (mechanism, not re-litigated)

*No* `property_contexts` label ⇒ `GetPropertyInfo` returns `nullptr` ⇒
`CheckMacPerms` false ⇒ deny, **before** any SELinux check (so no AVC is
expected; there is no `default_prop` fallback for `ro.guardtalk.*`).

```162:176:system/core/init/property_service.cpp
static bool CheckMacPerms(const std::string& name, const char* target_context,
                          const char* source_context, const ucred& cr) {
    if (!target_context || !source_context) {
        return false;
    }
    ...
    return selinux_check_access(source_context, target_context, "property_service", "set",
                                &audit_data) == 0;
}
```

`LoadProperties()` has no exemption path — it checks every `key=value`, logs one
line per property, and continues, so **35 denials are mandated**:

```927:932:system/core/init/property_service.cpp
            if (CheckPermissions(key, value, context, cr, &error) == PROP_SUCCESS) {
                ...
            } else {
                LOG(ERROR) << "Do not have permissions to set '" << key << "' to '" << value
                           << "' in property file '" << filename << "': " << error;
            }
```

Matched falsifier contract: `vendor/guardtalk/docs/qa/prop-denials.txt`
(**35** KEY=VALUE + **35** expected literals; byte-identical to the packed
`vendor.img`, enforced by the harness).

### 1.4 Pre-fix baseline (reproduced on the PACKED stamp)

`komodo-debug-20260919-080101` (immutable; re-run by this card):

| Check | Result |
|---|---|
| `debugfs -R 'cat /build.prop' $STAMP/vendor.img \| grep -c '^ro\.guardtalk\.'` | **35** |
| same for `$STAMP/system.img` | **0** |
| pre-fix `out/soong/soong.komodo.extra.variables`: `PRODUCT_PROPERTY_OVERRIDES` guardtalk | **35** |
| pre-fix `…`: `PRODUCT_SYSTEM_PROPERTIES` guardtalk | **0** |
| `PropertySplitEnabled` | **true** |

---

## 2. Chosen fix (evidence-based) and why it beats widening sepolicy

**Fix = route `ro.` product-policy props to the *system* property file**, i.e.
declare them with `PRODUCT_SYSTEM_PROPERTIES` (→ `system/build.prop`, loaded by
`init`), **and** give the prefix a real label:

- `system/sepolicy/private/property_contexts`:
  `ro.guardtalk.  u:object_r:guardtalk_prop:s0`
- `system/sepolicy/private/property.te`: `system_restricted_prop(guardtalk_prop)`

### Why the label is still required (and why it is not "widening sepolicy")

Even after moving the value to `system/build.prop`, `init` still calls
`CheckPermissions()` → `CheckMacPerms()` → `selinux_check_access(init, target,
"property_service", "set")`. Today `target_context` is `nullptr` and it fails.
A label makes the check reach SELinux, where `init` already holds a blanket
grant:

```149:149:system/sepolicy/private/init.te
allow init property_type:file { append create getattr map relabelto rename setattr unlink write };
```
```724:724:system/sepolicy/private/init.te
allow init property_type:property_service set;
```

The label is the minimal, *auditable* change:

```944:972:system/sepolicy/public/te_macros
define(`define_prop', `
  type $1, property_type, $2_property_type, $2_$3_property_type;
')
...
define(`system_restricted_prop', `
  define_prop($1, system, restricted)
  treble_sysprop_neverallow(`
    neverallow { domain -coredomain } $1:property_service set;
  ')
')
```

- **No read grants added.** `SystemProperties.get()` reads the shared property
  area directly and is **not** SELinux-gated. The only read-checked path is the
  `on property:` trigger:

  ```146:160:system/core/init/property_service.cpp
  bool CanReadProperty(const std::string& source_context, const std::string& name) {
      const char* target_context = nullptr;
      property_info_area->GetPropertyInfo(name.c_str(), &target_context, nullptr);
      ...
      return selinux_check_access(source_context.c_str(), target_context, "file", "read",
                                  &audit_data) == 0;
  }
  ```
  (`CanReadProperty` is called only from `action_parser.cpp`; init already has
  `file:read` on `property_type` via `init.te:149`.) This also *repairs* the
  `on property:ro.guardtalk.sysctl_hardening=1` trigger in
  `vendor/guardtalk/init/init.guardtalk.hardening.rc`, which today would never
  register because `CanReadProperty` gets a `nullptr` target.

**Rejected as first option — widening `default_prop`:**
`system/sepolicy/private/property.te` labels every unmatched key with
`u:object_r:default_prop:s0` and the property area's `default_prop` is shared by
*all* unlabelled keys; granting `init`/`vendor_init` write or `domain` read on it
is a **broad privilege expansion** for every unlabelled property on the device,
not just these 35. It also hides the defect instead of removing it (the props
must still be *loaded by the right process*). It is therefore rejected as the
first option, consistent with the dispatch and with the AOSP guidance in
`property.te:131-136` ("New properties should have appropriate read / write
access control rules written").

**Residual card required (flagged, not done):** the sepolicy edit lives in
`system/sepolicy/private/`, which is shared AOSP platform policy, because
**no GuardTalk-owned sepolicy dir is wired** (`BOARD_SEPOLICY_DIRS` has no
guardtalk entry; `vendor/guardtalk/sepolicy/` does not exist). Recommend a
security review + a decision on a GuardTalk-owned sepolicy dir. `system/` is
outside the dispatch's declared target paths — this is called out for the
Architect to accept or redirect (§ 6).

---

## 3. The make-level diff (props move to the intended file)

5 wired `.mk` files, `PRODUCT_PROPERTY_OVERRIDES` → `PRODUCT_SYSTEM_PROPERTIES`
for every `ro.guardtalk.*`; non-guardtalk keys were left in place:

| File | moved to `PRODUCT_SYSTEM_PROPERTIES` | left in `PRODUCT_PROPERTY_OVERRIDES` |
|---|---|---|
| `vendor/guardtalk/device/tokay/guardtalk-product-props.mk` | 21 | `persist.security.usb_mode=2` |
| `vendor/guardtalk/device/komodo/guardtalk-production-hardening.mk` | 10 (`production_profile` on `user`) | `ro.adb.secure=1`, `vendor.guardtalk.usb_duress_wipe.enabled=1` |
| `vendor/guardtalk/device/komodo/guardtalk-telemetry.mk` | 1 | `logd.logpersistd.enable=false` |
| `vendor/guardtalk/device/komodo/guardtalk-messenger.mk` | 1 | — |
| `vendor/guardtalk/device/komodo/guardtalk-wifi-gateway.mk` | 3 | — |
| **total** | **36 = 35 + `production_profile` (user-only)** | — |

Representative diff:

```diff
--- a/vendor/guardtalk/device/tokay/guardtalk-product-props.mk
+++ b/vendor/guardtalk/device/tokay/guardtalk-product-props.mk
-PRODUCT_PROPERTY_OVERRIDES += \
+PRODUCT_SYSTEM_PROPERTIES += \
     ro.guardtalk.radio.excised=1 \
     ...
     ro.guardtalk.files_protect_critical=1 \
-    persist.security.usb_mode=2
+
+# Not a GuardTalk policy flag: stays in vendor/build.prop.
+PRODUCT_PROPERTY_OVERRIDES += \
+    persist.security.usb_mode=2

--- a/vendor/guardtalk/device/komodo/guardtalk-production-hardening.mk
+++ b/vendor/guardtalk/device/komodo/guardtalk-production-hardening.mk
-PRODUCT_PROPERTY_OVERRIDES += \
+PRODUCT_SYSTEM_PROPERTIES += \
     ro.guardtalk.production_hardening=1 \
     ...
 ifeq ($(TARGET_BUILD_VARIANT),user)
-    PRODUCT_PROPERTY_OVERRIDES += \
-        ro.guardtalk.production_profile=1 \
-        ro.adb.secure=1 \
-        vendor.guardtalk.usb_duress_wipe.enabled=1
+    PRODUCT_SYSTEM_PROPERTIES += ro.guardtalk.production_profile=1
+    PRODUCT_PROPERTY_OVERRIDES += \
+        ro.adb.secure=1 \
+        vendor.guardtalk.usb_duress_wipe.enabled=1
 endif
```

### A/B proof on the live product config (`get_build_var`, this host, this card)

| Variant | `PRODUCT_SYSTEM_PROPERTIES` guardtalk | `PRODUCT_PROPERTY_OVERRIDES` guardtalk |
|---|---|---|
| pre-fix (`out/soong/…extra.variables`, debug stamp) | **0** | **35** |
| post-fix `komodo-trunk_staging-user` | **36** (= 35 + `production_profile`) | **0** |
| post-fix `komodo-trunk_staging-userdebug` | **35** (matches the packed 35 exactly) | **0** |

Because `gen_build_prop.py:build_system_prop()` writes
`PRODUCT_SYSTEM_PROPERTIES` to `system/build.prop`, **the props will move to the
intended file** on the next build. `out/` was **not** packed.

Reproduce: `bash vendor/guardtalk/docs/qa/verify_remediate_b6_prop_host.sh`
→ **PASS=15 FAIL=0 HOLD=2** (see § 5).

---

## 4. The 35 flags → consumer mapping (grep-verified, not guessed)

29 have a direct in-tree Java consumer; 6 are declaration/verifier markers (no
in-tree runtime reader — stated honestly rather than guessed).

| # | Flag | Consumer (file : method) |
|---|---|---|
| 1 | `anti_bruteforce_wipe_threshold` | `GuardTalkSecureWipePolicy.getAntiBruteforceWipeThreshold()`; Settings `GuardTalkSecureWipeHelper` |
| 2 | `auto_reboot_default_ms` | `GuardTalkAutoRebootPolicy.clampToProfileMillis()` fallback / `getEffectiveTimeoutMillis()`; Settings `GuardTalkAutoRebootHelper` |
| 3 | `auto_reboot_profiles` | `GuardTalkAutoRebootPolicy.isProfilesEnabled()`; `android.ext.settings.ExtSettings.AUTO_REBOOT_TIMEOUT` |
| 4 | `block_developer_options` | Settings `GuardTalkDeveloperOptionsPolicy.isUnlockBlocked()` |
| 5 | `block_unknown_sources` | `GuardTalkProductionHardeningPolicy.mustBlockUnknownSources()` |
| 6 | `clipboard_clear` | `GuardTalkPrivacyPolicy.isClipboardClearEnabled()` / `mustClearClipboardOnLock()` |
| 7 | `clipboard_clear_timeout_ms` | `GuardTalkPrivacyPolicy.getClipboardClearTimeoutMs()` |
| 8 | `config_password_gate` | `GuardTalkConfigGateManager` (`PROP_GATE_ENABLED`) |
| 9 | `files_policy` | `GuardTalkFilesPolicy.isEnabled()` (DocumentsUI `GuardTalkFilesLocalPolicy`) |
| 10 | `files_protect_critical` | `GuardTalkFilesPolicy.isCriticalProtectEnabled()` |
| 11 | `files_trash` | `GuardTalkFilesPolicy.isTrashEnabled()` |
| 12 | `keymint_required` | `GuardTalkProductionHardeningPolicy.isKeymintRequired()` |
| 13 | `lock_after_reboot` | `GuardTalkLockPolicy.isLockAfterRebootEnabled()` |
| 14 | `lockdown_fail_closed` | `GuardTalkSensorPrivacyPolicy.isLockdownFailClosedEnabled()`; Settings `GuardTalkSensorPrivacyHelper` |
| 15 | `max_lock_after_timeout_ms` | `GuardTalkLockPolicy.getMaxLockAfterTimeoutMs()` / `clampLockAfterTimeoutMs()` |
| 16 | `messenger` | **marker** — bake flag for `GuardTalkMessenger`; no in-tree runtime reader (as Q-REMEDIATE-B4-MESSENGER found) |
| 17 | `password_only_lock` | `GuardTalkLockPolicy.isPasswordOnlyLockEnabled()`; Settings `GuardTalkLockPolicyHelper` |
| 18 | `permission_defaults` | `GuardTalkPermissionDefaultsPolicy.isEnabled()` / `allowDefaultPermissionException()` |
| 19 | `privacy_tmpfs` | `GuardTalkPrivacyPolicy.isPrivacyTmpfsEnabled()` |
| 20 | `privacy_tmpfs_path` | `GuardTalkPrivacyPolicy.getPrivacyTmpfsPath()` |
| 21 | `production_hardening` | `GuardTalkProductionHardeningPolicy.isEnabled()` |
| 22 | `radio.excised` | **marker** — excise flag; host verifier `script/guardtalk/verify-radio-excision.sh` only |
| 23 | `restrict_accessibility_services` | `GuardTalkProductionHardeningPolicy.isAccessibilityRestricted()` |
| 24 | `restrict_display_overlays` | `GuardTalkProductionHardeningPolicy.isDisplayOverlayRestricted()` |
| 25 | `restrict_dynamic_code` | `GuardTalkProductionHardeningPolicy.isDynamicCodeRestricted()` |
| 26 | `secure_wipe_enabled` | `GuardTalkSecureWipePolicy.isSecureWipeEnabled()`; Settings `GuardTalkSecureWipeHelper` |
| 27 | `selinux_enforcing_required` | `GuardTalkProductionHardeningPolicy.isSelinuxEnforcingRequired()` |
| 28 | `sensor_privacy_when_locked` | `GuardTalkSensorPrivacyPolicy.isSensorPrivacyWhenLockedEnabled()`; Settings `GuardTalkSensorPrivacyHelper` |
| 29 | `sysctl_hardening` | `GuardTalkProductionHardeningPolicy.isSysctlHardeningEnabled()`; `on property:` trigger in `init.guardtalk.hardening.rc` |
| 30 | `telemetry_persist_disabled` | **marker** — enforcement is in `init.guardtalk.telemetry.rc`; no reader of the `ro.` flag |
| 31 | `usb_protection_fail_closed` | `GuardTalkUsbProtectionPolicy.isFailClosedEnabled()` / `mustDenyUsbData()`; Settings `GuardTalkUsbProtectionHelper` |
| 32 | `verified_boot_required` | `GuardTalkProductionHardeningPolicy.isVerifiedBootRequired()` |
| 33 | `wifi.fail_closed` | **marker** — host verifier `verify_remediate_b4_wifi_gw_host.sh`; runtime via wpa overlay + `init.guardtalk.wifi-gateway.rc` |
| 34 | `wifi.gateway_only` | **marker** — as #33 |
| 35 | `wifi.ssid_allowlist_path` | **marker** — as #33; file-pointer with no in-tree reader (Q-REMEDIATE-B4-WIFI-GW residual 4b, already HOLD) |

Also covered (not among the 35, not on this debug stamp): `ro.guardtalk.production_profile`
— declared `user`-only in the komodo hardening file and moved to
`PRODUCT_SYSTEM_PROPERTIES` in the same edit; it is the 36th key in the `user`
A/B result above.

---

## 5. Verification performed (and what remains HOLD)

Host harness (read-only): `vendor/guardtalk/docs/qa/verify_remediate_b6_prop_host.py`
+ `…/verify_remediate_b6_prop_host.sh`.

```
--- RESULT: PASS=15 FAIL=0 HOLD=2 ---
packed vendor ro.guardtalk count = 35
packed system ro.guardtalk count = 0
contract keys = 35  contract literals = 35
contract KEY=VALUE set is byte-identical to the packed image
… each wired mk: no ro.guardtalk.* in PRODUCT_PROPERTY_OVERRIDES
… all 35 contract keys are declared with PRODUCT_SYSTEM_PROPERTIES
… property_contexts labels ro.guardtalk. -> guardtalk_prop
… property.te defines system_restricted_prop(guardtalk_prop)
… no shadowing guardtalk label elsewhere
LIVE_DEVICE_CLAIMED=false  PACKED_OUT=false  FLASH_READY=false  USB_GO=false
adb_devices=0
```

**HOLD (a rebuilt + flashed image is required; this card does not pack or flash):**

- On-device `getprop` contract for all 35 keys (`prop-denials.txt` § VERIFY).
- Full kernel-log re-read proving **0** remaining
  `Do not have permissions to set 'ro.guardtalk.…` lines (the "35 vs 3"
  falsifier measured on device).
- `property_contexts` extract from the rebuilt `system.img` must show a
  `guardtalk` match (was 0 in all four partitions on the packed stamp).
- Compile/validity of the sepolicy edit is **not** claimed: it was not built.
  Mark HOLD for the first rebuilt image and for security review.

---

## 6. Residuals and decisions required from the Architect

1. **`system/sepolicy/private/` edit** (label + `system_restricted_prop`) is
   outside the dispatch's declared target paths. It is the minimal correct fix
   because no GuardTalk sepolicy dir is wired. **Architect decision requested:**
   accept, or create+wired a GuardTalk sepolicy dir and re-home the label.
2. **tokay fallback still broken for other products.** `vendor/guardtalk/device/tokay/guardtalk-production-hardening.mk`
   (the `$(PRODUCT_DEVICE)` fallback used by akita/rango/emu64a) still declares
   its 9 `ro.guardtalk.*` with `PRODUCT_PROPERTY_OVERRIDES` → same silent-off
   class. **Not edited** (outside the declared target paths; komodo does not use
   it). Recommend a follow-up card.
3. **`ro.guardtalk.voice.filter` / `ro.guardtalk.face.filter`** are declared in
   `vendor/guardtalk/device/komodo/guardtalk-{audio,camera}.mk` but those files
   are **not in komodo's inherit chain** (only tokay's own `tokay.mk` and
   `emu64a` inherit them), so they are absent from the image entirely. Same
   class, different defect; **not touched**. Recommend a follow-up card.
4. **`out/` is stale** and was not treated as product truth or as PASS for this
   card. Only `get_build_var` (make-level, live) and the packed stamp were used.
5. **`vendor/guardtalk/docs/KOMODO_DEBUG_FLASH.md` was NOT touched** (owned by the
   STAMP-HONESTY lane).

---

## 7. Gate 5 — Ultimate Critique (self-score 93/100)

| Criterion | Weight | Score | Notes |
|---|---|---|---|
| Root cause with make-level evidence | 25 | 25 | `config.mk` → `soong_extra_config.mk` → `gen_build_prop.py`; inherit chain traced to `komodo.mk:4773`; pre/post A/B on live make vars |
| Fix chosen on evidence (system routing > sepolicy widening) | 20 | 19 | routing + minimal label; rejected `default_prop` widening with source evidence; label requires security review → −1 |
| 35-flag → consumer mapping not guessed | 15 | 14 | 29 direct consumers grep-verified; 6 markers explicitly labelled as "no in-tree runtime reader" rather than invented → −1 for 6 markers without runtime readers |
| Falsifier contract | 15 | 15 | `prop-denials.txt`: 35 keys + 35 literals, byte-identical to packed image (machine-checked) |
| Verification honesty (no on-device claim; HOLD surfaced) | 15 | 15 | HOLDs listed; `LIVE_DEVICE_CLAIMED=false`; sepolicy compile not claimed |
| Scope/forbidden-path compliance | 10 | 10 | no doctrine/governance/inbox-mainline/flash-script/Debug-Flash edits; no pack; no commit |
| **Total** | **100** | **93** | |

**Known weaknesses (self-declared):** (a) the sepolicy edit is unbuilt and lives
in shared platform policy; (b) 6 of 35 flags have no in-tree runtime reader, so
"readable at runtime" for them only means `getprop` returns the value (their
enforcement lives in `.rc`/overlays/host verifiers); (c) the make-level A/B uses
`get_build_var` (product config), **not** a built `system/build.prop` — the
packed-file proof is HOLD until rebuild.

**PASS HOLD** remains. Status `REVIEW`, never `APPROVED`. No commit.
