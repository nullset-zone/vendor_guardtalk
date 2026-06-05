# Face persona filter (DEC-GT-004)

GuardTalkOS applies a **face persona mask** on front-camera preview when CameraX **Beauty** extension is used.

## Components

| Piece | Path |
|-------|------|
| C++ pipeline | `vendor/guardtalk/camera/pipeline/FacePipeline.*` |
| JNI | `vendor/guardtalk/camera/jni/GuardTalkFaceJni.cpp` → `libguardtalkface_jni.so` |
| Camera extension | `vendor/guardtalk/camera/extensions/` → `BeautyAdvancedExtenderImpl` |
| Settings | `vendor/guardtalk/apps/GuardTalkFace/` |
| Product | `vendor/guardtalk/device/tokay/guardtalk-camera.mk` |

## Properties

| Property | Default | Meaning |
|----------|---------|---------|
| `ro.guardtalk.face.filter` | `1` | Feature shipped |
| `persist.vendor.guardtalk.face.enabled` | `0` | Opt-in master switch |
| `persist.vendor.guardtalk.face.persona` | `0` | 0 neutral … 4 warm |
| `persist.vendor.guardtalk.face.quality` | `1` | 0 lite / 1 balanced / 2 max |

## Build and verify

```bash
source build/envsetup.sh && lunch tokay-cur-user
m libguardtalkface_jni androidx.camera.extensions.impl.guardtalk GuardTalkFace vendorimage -j$(nproc)
vendor/guardtalk/scripts/verify-face-filter.sh
```

## On-device

1. Open **GuardTalk Face**, enable persona and pick preset.
2. Open a CameraX app that supports **Beauty** extension (not stock Google Camera).
3. Confirm preview center region shifts tone when persona ≠ neutral.

## Limitations (v1)

- Persona uses center-ellipse YUV tint (no TFLite face mesh yet).
- Requires apps using OEM Camera2 advanced Beauty extension.
- Default **disabled** — user must opt in.
