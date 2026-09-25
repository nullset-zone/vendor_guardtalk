# Q-REMEDIATE-B4-CHECKIN evidence (item 20)

Independent rematch. Backend/Architect dumps **not trusted**. Gate -1 in-process.
No USB GO. No commit. Never APPROVED. Not device-fixed. **PASS HOLD remains.**

Stamp: 2026-09-16T13:51:00Z

## Commands re-run

```
python3 -m unittest discover -s vendor/guardtalk/checkin/host -p 'test_*.py' -v
→ 13 tests, 0 failed, OK

bash vendor/guardtalk/checkin/host/verify_host.sh
→ PASS=21 FAIL=0 HOLD=2 EXIT=0

bash vendor/guardtalk/docs/qa/verify_remediate_b4_checkin_host.sh
→ PASS=39 FAIL=0 HOLD=2 EXIT=0
```

## Lunch (independent)

Session-only `GIT_CONFIG_COUNT=1` `safe.directory` = `vendor/adevtool`. `set +u` around `envsetup`. Combo `komodo-trunk_staging-user`.

| Var | Value | Result |
|-----|-------|--------|
| TARGET_PRODUCT | komodo | PASS |
| TARGET_BUILD_VARIANT | user | PASS |
| GuardTalkCheckin in PRODUCT_PACKAGES | PRESENT (line 35 of dump) | PASS |

Dump: `vendor/guardtalk/docs/qa/_artifacts/Q-REMEDIATE-B4-CHECKIN_PRODUCT_PACKAGES.txt`

## Interval / contract

| Check | Result |
|-------|--------|
| Kotlin `INTERVAL_S = 12 * 60 * 60` | PASS |
| Python `INTERVAL_S = 12 * 60 * 60` | PASS |
| schema `interval_s` const **43200** | PASS |
| JobScheduler `setPeriodic(INTERVAL_MS)` | PASS |

## No public C2 / no secrets

| Check | Result |
|-------|--------|
| No public URL C2 in app src / mk / contract.py | PASS |
| `payload.schema.json` `$schema` is json-schema.org **meta URI** (not C2) | PASS (not FAIL) |
| No baked v3 onion / no baked SOCKS `127.0.0.1:9050` | PASS |
| No pem/pk8/key/.env under checkin paths | PASS |
| Unittest `test_reject_public_c2` | PASS |

## HOLDs (honest; not FAIL)

| HOLD | Why |
|------|-----|
| Tor admin live visibility | Gateway / Tor admin UI **ABSENT** in this GrapheneOS-worktree |
| On-device JobScheduler | `adb devices` empty |

## Suite log

`vendor/guardtalk/docs/qa/Q-REMEDIATE-B4-CHECKIN_SUITE.out`
