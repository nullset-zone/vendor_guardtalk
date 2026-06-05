# Independent audit: DEC-GT-004 face persona filter

**Date:** 2026-06-05  
**Scope:** code-review + wiring + build acceptance  
**Verdict:** **CONDITIONAL PASS** — build/verify green; on-device CameraX Beauty path pending hardware QA.

## Evidence

| Check | Result |
|-------|--------|
| `m libguardtalkface_jni androidx.camera.extensions.impl.guardtalk GuardTalkFace vendorimage` | PASS |
| `verify-face-filter.sh` | 0 failures |
| `guardtalk_face_pipeline_test` (host) | PASS |
| AOSP `advancedSample` extension replaced | PASS (permissions removed) |
| Opt-in default `persist.vendor.guardtalk.face.enabled=0` | PASS |

## Findings

### F1 (MEDIUM) — v1 uses geometric persona mask, not ML face mesh

Center-ellipse YUV tint only. Acceptable for DEC-GT-004 v1 per architect plan; document TFLite landmark path for v2.

### F2 (LOW) — Camera extension scope limited to Beauty + front camera

Apps must use CameraX **Beauty** advanced extension. Stock Google Camera may not invoke OEM extension.

### F3 (FIXED) — JNI link needed `libcutils` on `libguardtalkface_jni`

Static pipeline archive did not propagate property symbols under LTO.

### F4 (FIXED) — Host `cc_test` device link failure

Set `device_supported: false` on `guardtalk_face_pipeline_test`.

### F5 (LOW) — Legal/consent UI present

GuardTalkFace includes consent copy; default disabled.

## Production checklist

- [x] C++ pipeline + JNI
- [x] OEM Camera2 extension jar + permissions
- [x] GuardTalkFace priv-app
- [x] Product properties + package removal of AOSP advanced sample
- [x] Host unit test + verify script
- [ ] On-device Beauty extension preview validation
- [ ] TFLite face detector (v2)

## Recommendation

Ship to hardware QA. Enable persona in GuardTalk Face, test with CameraX extension sample app. Escalate to TFLite/EdgeTPU if ellipse mask insufficient.
