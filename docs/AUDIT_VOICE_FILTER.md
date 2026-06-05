# Independent audit: DEC-GT-003 mic voice filter

**Date:** 2026-06-05  
**Auditor scope:** code-review + wiring + progress  
**Verdict:** **CONDITIONAL PASS** — host/build acceptance green; on-device effect attach pending flash validation.

## Evidence reviewed

| Check | Result |
|-------|--------|
| `m libguardtalkvoicesw GuardTalkVoice guardtalk_audio_effects_config.xml` | PASS |
| `guardtalk_voice_pitch_shifter_test` (host) | PASS |
| `verify-voice-filter.sh` | 0 failures |
| `vendor/etc/audio_effects_config.xml` in `out/` | Present with preprocess + guardtalk effect |
| `libguardtalkvoicesw.so` in `vendor/lib64/soundfx/` | Present |

## Findings

### F1 (MEDIUM) — On-device effect registration unverified

Pixel 9 uses Google AoC AIDL `android.hardware.audio.effect` HAL. Config is shipped to `vendor/etc/audio_effects_config.xml` (first match in `audio_get_configuration_paths()`). **Must confirm on hardware** that `IFactory` loads `guardtalk_voice_filter` and preprocess chain attaches to mic sources.

**Mitigation:** `docs/VOICE_FILTER.md` on-device section; flash + `dumpsys media.audio_flinger` / logcat `AHAL_*` checks.

### F2 (LOW) — DSP v1 is lightweight

`VoicePitchShifter` uses linear interpolation + preset ratios, not WSOLA/SoundTouch. Acceptable for DEC-GT-003 v1 scope; document v2 upgrade path.

### F3 (LOW) — Settings uses `setprop` subprocess

`GuardTalkVoice` calls `Runtime.exec("setprop")` instead of hidden `SystemProperties.set`. Works for platform priv-app; acceptable.

### F4 (FIXED) — Feature flag gating

Added `GUARDTALK_VOICE_FILTER` in `guardtalk-flags.mk` and wrapped `guardtalk-audio.mk`.

## Production checklist

- [x] C++ AIDL preprocessing effect builds and installs
- [x] Product properties and effects XML wired
- [x] Priv-app control plane
- [x] Host unit test + verify script
- [ ] On-device timbre change per preset (requires flash)
- [ ] Latency budget measurement (<20 ms target per architect plan)

## Recommendation

Ship to hardware QA. If AoC HAL ignores vendor config, escalate to vendor HAL config merge or Google whitechapel audio extension hook (out of scope for v1 C++ path).
