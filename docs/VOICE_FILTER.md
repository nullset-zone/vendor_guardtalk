# Mic DSP voice filter (DEC-GT-003)

GuardTalkOS applies a vendor mic preprocessing effect on Pixel 9 (`tokay`) capture streams.

## Components

| Piece | Path |
|-------|------|
| DSP core | `vendor/guardtalk/audio/dsp/VoicePitchShifter.*` |
| AIDL effect HAL lib | `vendor/guardtalk/audio/aidl/GuardTalkVoiceSw.*` → `libguardtalkvoicesw.so` |
| Effects config | `vendor/guardtalk/audio/config/audio_effects_config.xml` |
| Settings priv-app | `vendor/guardtalk/apps/GuardTalkVoice/` |
| Product hook | `vendor/guardtalk/device/tokay/guardtalk-audio.mk` |

## Properties

| Property | Default | Meaning |
|----------|---------|---------|
| `ro.guardtalk.voice.filter` | `1` | Feature shipped on GuardTalk builds |
| `persist.vendor.guardtalk.voice.enabled` | `1` | Master enable |
| `persist.vendor.guardtalk.voice.preset` | `0` | `0` natural … `4` robot |

## Build and verify

```bash
source build/envsetup.sh && lunch tokay-cur-user
m libguardtalkvoicesw GuardTalkVoice guardtalk_audio_effects_config.xml vendorimage -j$(nproc)
vendor/guardtalk/scripts/verify-voice-filter.sh
```

Host DSP test:

```bash
m guardtalk_voice_pitch_shifter_test -j$(nproc)
out/host/linux-x86/nativetest64/guardtalk_voice_pitch_shifter_test/guardtalk_voice_pitch_shifter_test
```

## On-device checks

1. Install / flash build with voice filter packages.
2. Open **GuardTalk Voice** app, toggle enable and presets.
3. Record voice memo or use `adb shell tinycap` on mic path; confirm timbre changes per preset.
4. `adb shell getprop persist.vendor.guardtalk.voice.preset` reflects UI changes.

## Presets

- **Natural** — bypass (pitch 1.0)
- **Deep** — lower pitch (~0.82)
- **Bright** — higher pitch (~1.14)
- **Masked** — slight attenuation + mild shift
- **Robot** — pitch shift + light quantization

## Upstream notes

Effect UUIDs are GuardTalk-specific (`dec3b103-b1a2-4034-8c7d-9e0f12340100/01`). Config merges AOSP AIDL libraries with `guardtalk_voice_filter` on `mic`, `camcorder`, `voice_recognition`, and `voice_communication` streams.
