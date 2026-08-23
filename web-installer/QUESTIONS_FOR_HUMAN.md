# QUESTIONS_FOR_HUMAN — GuardTalkOS WebInstaller

Every `// confirm` from the build prompt, plus gaps the sources do not answer.
Rule: nothing here is invented around. Items marked **BLOCKING** stop the phases they gate.

| # | Step / area | Question | Blocking? |
|---|-------------|----------|-----------|
| Q-01 | All screens (identity) | `GuardTalkOS_Web_Brief_v1_0.md` is absent from this repo — its §0 laws, §4 register, §6.5–6.7, §8 conventions, §9 stack, §17–19 cannot be inherited. Provide the file or authorise building from Executive Summary + build prompt alone. | **YES** — blocks screen copy/styling phases; foundations proceed |
| Q-02 | All screens (identity) | `GuardTalkOS_Claude_Code_Build_Prompt_v1_0.md` (site build prompt: tokens, primitives, status.json contract, lib/privacy, lib/claims, lint rules, .onion export target) is absent. No os.guardtalk.io site tree exists in this repo today. Provide it or authorise a fresh statically-exported site scaffold under which `/install` becomes a route group. | **YES** — same scope as Q-01 |
| Q-03 | All screens (identity) | `guardtalk_brand_book.html` is absent (only `GuardTalkOS_System_Theme.html` asset pack exists under `vendor/guardtalk/branding/`). Confirm whether the System Theme HTML carries the binding identity tokens, or supply the Brand Book. | YES — identity tokens |
| Q-04 | Step 0 / step 2 | Release-key fingerprint and its publication channel (where the user cross-checks it). Rendered as mono placeholder `// confirm`. | No — placeholder ships |
| Q-05 | Step 1 | Releases onion address (`// confirm`) and clearnet mirror URL for `/install`. | No — placeholder ships |
| Q-06 | Step 0 | Full supported-codename matrix. Only `tokay`, `rango` grounded in Executive Summary §3; remaining Pixel 8/9 family codenames `// confirm`. | No — two confirmed targets ship |
| Q-07 | Step 4 / 6 | Partition layout and chained-`vbmeta_*` descriptor requirements for Pixel 8/9 (`vbmeta_system`, `vbmeta_vendor` etc.). Installer stops the flow with the reason if a chain is required but unknown. `// confirm partition layout`. | Partially — flow-safe stop ships |
| Q-08 | `/install/update` step 5 | Sideload vs fastboot-only update path (`// confirm`). Fastboot path implemented first-class; recovery-sideload UI deferred until confirmed. | No — fastboot path ships |
| Q-09 | Step 3 flow 1 | KDF availability in-browser for encrypted key export: Argon2id via WebCrypto is unavailable natively; confirm acceptable posture of PBKDF2-SHA256 high-iteration fallback vs shipping WASM Argon2id. Prompt pre-authorises PBKDF2 fallback as `// confirm`. | No — PBKDF2 fallback ships, labelled |
| Q-10 | Update policy | In-OS updater constraint wording for ARCHITECTURE.md (verify against user key + on-device confirmation) — confirm final sentence for the design-constraint record. | No |
| Q-11 | Definition of Done | Real-device validation: NONE is possible in this session (no physical Pixel 8/9 attached). All device interaction is simulated. This limitation is stated in PROGRESS.md and every report. Confirm who runs real-device validation before any public release. | Recorded — not code-blocking |
| Q-12 | Attribution | Exact GrapheneOS `<LineageNote>` wording (Executive Summary §5 marks counsel confirmation pending). Ships with draft wording + `// confirm with counsel`. | No |
| Q-13 | Whole installer | DEC-009 reconciliation (D-011): confirm that machine-driven execution staying dry-run-only, with live flashing enabled only by a human launch-time flag flip on real hardware, is the accepted reading of "production-ready" for alpha. | No — safe default ships |
| Q-14 | Step 0 / devices | Is `akita` (Pixel 8a) a supported target or does it remain experimental? Exec Summary grounds only {tokay, rango}; existing allowlist carries akita. | No — experimental flag ships |

## Missing-source register (mirrors DECISION_LOG D-009)

- [ ] `GuardTalkOS_Web_Brief_v1_0.md`
- [ ] `GuardTalkOS_Claude_Code_Build_Prompt_v1_0.md`
- [ ] `guardtalk_brand_book.html`

## Pre-taken decisions (do NOT re-ask)

See `DECISION_LOG.md` D-001…D-010. Notably: no OTA while alpha (D-004), three equal key flows
with silent-default forbidden (D-005), zero-runtime-network CSP + no-connect test (D-006),
key-custody guarantees (D-007), `ultimate_critique` skipped (D-008).
