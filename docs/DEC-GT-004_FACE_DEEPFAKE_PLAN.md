# DEC-GT-004 — Real-time face deepfake (architect plan)

**Device:** Pixel 9 (`tokay`) / GrapheneOS `16-qpr2` / GuardTalkOS  
**Prerequisites:** `DEC-GT-002` (modem excision) ✅, `DEC-GT-003` (voice filter) ✅  
**Status:** APPROVED FOR PLANNING — not dispatched  
**Architect:** per `aegis-architect.md` / DEC-011 (no implementation code)

---

## 1. Goal

Provide **real-time face transformation** on **outgoing camera preview and capture** (front camera primary): user selects a **persona / face mask** so video calls, recordings, and camera apps see a synthetic face instead of the live biometric.

**v1 non-goals:** perfect identity cloning of arbitrary third parties, cloud inference, training on-device, system-wide hook inside proprietary Google Camera HAL, undetectable adversarial deepfakes.

**Product note:** Document consent, jurisdiction, and abuse policy before ship. This is a **privacy persona** feature, not covert impersonation tooling.

---

## 2. Language decision — Rust vs alternatives

Original brief specified Rust. On Pixel 9 + Android 16, **integration cost dominates** ML cost. Recommendation mirrors DEC-GT-003 (voice): **C++ for native pipeline**, **Kotlin for control plane**, **Rust optional v2** behind a C ABI if a portable ONNX core is needed.

| Language | Integration on tokay | ML runtime | Camera path | Build (Soong) | Verdict |
|----------|----------------------|------------|-------------|---------------|---------|
| **C++** | **Best** — Camera2 Extension native lib, EGL, `libtflite`, EdgeTPU delegate already in tree | TFLite + `libedgetpu_tflite_compiler` | `frameworks/ex/camera2/extensions/` OEM pattern | Mature | **v1 default** |
| **Kotlin/Java** | **Best** for Settings, extension service binder | Too slow for per-frame inference | `service_based_camera_extensions` glue | Easy | **Control plane only** |
| **Rust** | Weak — `cdylib` + NDK + Camera buffer FFI + Soong `rust_*` modules | `ort` crate strong on desktop; NNAPI EP on Android needs care | No first-class Camera Extension samples | Harder | **v2 optional** (inference core) |
| **Python** | N/A on device | N/A | N/A | N/A | **Reject** |

### Why not Rust for v1

1. **Pixel ML stack is TFLite-centric** — `vendor/google_devices/tokay` ships `libedgetpu_tflite_compiler`, `hal_neuralnetworks` + EdgeTPU, existing `.tflite` models in `vendor/etc/`.
2. **Camera OEM path is C++/Java** — AOSP ships `advancedSample` and `service_based_camera_extensions`; no Rust template.
3. **Precedent** — DEC-GT-003 shipped faster as C++ AIDL effect + Kotlin priv-app than a Rust `cdylib` would have.
4. **Rust face-swap projects** (`face-swap`, `deep_faceswap`) target desktop capture (`nokhwa`, `egui`), not Camera2 YUV_420_888 → GPU → display.

### When Rust *does* make sense (v2)

- Portable ONNX graph (RetinaFace + InSwapper) with tests on host, exported as `staticlib` + thin C++ shim.
- Only after v1 pipeline proves frame budget on hardware.

---

## 3. Recommended architecture (v1)

```text
┌─────────────────────────────────────────────────────────────────┐
│  Camera app / VoIP / Recorder (Camera2 / CameraX)               │
└────────────────────────────┬────────────────────────────────────┘
                             │ PREVIEW / VIDEO / STILL
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  cameraserver → Camera2 Extension (GuardTalk Advanced Extender) │
│  vendor/guardtalk/camera/extensions/                            │
│    SessionProcessorImpl → ImageProcessorImpl (C++)              │
└────────────────────────────┬────────────────────────────────────┘
                             │ YUV / RGBA buffers
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  libguardtalkface.so (C++)                                      │
│    FaceDetector (TFLite, 320×320)                              │
│    FaceAligner (landmarks)                                      │
│    FaceSwapper (TFLite or GPU shader composite v1 lite)          │
│    EdgeTPU delegate when available                              │
└────────────────────────────┬────────────────────────────────────┘
                             │ processed buffer
                             ▼
┌─────────────────────────────────────────────────────────────────┐
│  Output surface → app / encoder                                 │
└─────────────────────────────────────────────────────────────────┘

Control plane (parallel):
  GuardTalkFace priv-app (Kotlin) → persist.vendor.guardtalk.face.*
  Extension service / permissions XML (vendor)
```

### Integration path (ordered by preference)

| # | Path | Scope | Effort |
|---|------|-------|--------|
| **A** | **Camera2 Advanced Extension** (`ImageProcessorImpl`) | Apps using CameraX extensions API | **Medium** — upstream-safe |
| B | Service-based extension + forwarder | Same, Java service wrapper | Medium+ |
| C | Priv-app `ImageReader` sidecar | Single app only | Low scope, **not system-wide** |
| D | Virtual camera (`virtualcamera`) | Inject alternate device | High UX risk |
| E | Patch `cameraserver` / Google HAL | Global | **Forbidden** for merge hygiene |

**Choose A** for GuardTalkOS v1.

### Inference stack (v1)

| Stage | Model (start) | Runtime | Target res |
|-------|---------------|---------|------------|
| Detect | BlazeFace / MediaPipe face short (convert to TFLite) | TFLite CPU or EdgeTPU | 320×320 |
| Align | 5-point from detector | C++ geometry | — |
| Swap v1 lite | **2D warp + persona texture** (no GAN) | OpenGL/EGL | 720p max |
| Swap v2 | InSwapper-class TFLite (quantized) | TFLite + GPU delegate | 480p internal |

**v1 ships "persona mask"** (avatar overlay with face tracking) before full GAN swap — cuts risk, meets privacy goal, fits thermal budget.

### Properties

| Property | Default | Meaning |
|----------|---------|---------|
| `ro.guardtalk.face.filter` | `1` | Feature present |
| `persist.vendor.guardtalk.face.enabled` | `0` | Opt-in (unlike voice — higher legal surface) |
| `persist.vendor.guardtalk.face.persona` | `0` | Persona index |
| `persist.vendor.guardtalk.face.quality` | `1` | `0` lite / `1` balanced / `2` max |

---

## 4. Vendor layout (proposed)

```text
vendor/guardtalk/
├── camera/
│   ├── extensions/          # OEM Camera2 extension (Java + C++)
│   ├── ml/                    # TFLite models + loader
│   ├── pipeline/              # C++ detect/align/composite
│   └── Android.bp
├── apps/GuardTalkFace/        # Settings + persona picker
├── device/tokay/guardtalk-camera.mk
├── sepolicy/guardtalk_face.te
├── scripts/verify-face-filter.sh
└── docs/FACE_FILTER.md
```

Hook: `guardtalk-tokay.mk` → `inherit guardtalk-camera.mk` (same pattern as audio).

---

## 5. Task chain (dispatch order)

| ID | Agent | Summary | Est. |
|----|-------|---------|------|
| **T-GT-FACE-001** | Backend | Spike: `advancedSample` fork → process one YUV frame passthrough on tokay | 16h |
| **T-GT-FACE-002** | Backend | C++ `FacePipeline` + BlazeFace TFLite + landmark warp (no swap) | 24h |
| **T-GT-FACE-003** | Backend | Persona composite (GL) + extension `ImageProcessorImpl` integration | 32h |
| **T-GT-FACE-004** | Backend | Product: extension manifest, sepolicy, `guardtalk-camera.mk`, models in vendor | 16h |
| **F-GT-FACE-005** | Frontend | `GuardTalkFace` priv-app: enable, persona, quality | 16h |
| **T-GT-FACE-006** | Backend | Properties + extension read path; opt-in defaults | 8h |
| **Q-GT-FACE-010** | QA | Matrix: CameraX app, Meet/Zoom WebRTC, thermal, latency, power | 24h |

**Total ~136h** (v1 persona mask). Full GAN swap adds **+80–120h** (T-GT-FACE-020..022).

---

## 6. Acceptance criteria (v1)

- [ ] Front-camera preview in a CameraX test app shows persona overlay when enabled.
- [ ] ≤ **3 frames** additional latency at 720p30 on tokay (measure via systrace).
- [ ] CPU + NPU combined **< 25%** sustained on 5 min call (thermal throttle not tripped).
- [ ] Disabled path = bit-exact passthrough (no quality regression).
- [ ] `verify-face-filter.sh` passes on `out/target/product/tokay`.
- [ ] Settings toggle survives reboot (`persist.vendor.guardtalk.face.*`).
- [ ] Legal copy in app + Settings: user must enable explicitly.

---

## 7. Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Google Camera ignores extensions | High | Target CameraX + third-party VoIP; document limitation |
| Thermal throttling | High | Default 480p internal, EdgeTPU, lite persona v1 |
| Model license (InsightFace etc.) | Medium | v1 use royalty-free BlazeFace + in-house persona art |
| SELinux denials on extension | Medium | Copy `hal_camera_default` / `cameraserver` patterns from sample |
| Abuse perception | High | Opt-in default off; onboarding consent |

---

## 8. Rust migration path (v2, optional)

```text
T-GT-FACE-020  Export ONNX swap graph to TFLite OR Rust staticlib + C++ shim
T-GT-FACE-021  Host parity tests (desktop ort vs device TFLite)
```

Only pursue if v1 persona mask is insufficient for product.

---

## 9. Architect verdict

| Question | Answer |
|----------|--------|
| Fastest language? | **C++** (pipeline) + **Kotlin** (UI) |
| Keep Rust? | **Defer** to v2 inference core |
| Block GuardTalkOS on this? | **No** — Phase 4 R&D after VPN/DNS (#5–6) or parallel if staffed |
| Recommended first milestone? | T-GT-FACE-001 spike + passthrough extension |

---

*DEC-GT-004 — Architect plan — 2026-06-05*
