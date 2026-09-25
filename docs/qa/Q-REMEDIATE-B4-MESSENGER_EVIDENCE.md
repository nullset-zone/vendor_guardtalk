# Q-REMEDIATE-B4-MESSENGER evidence (item 19)

Independent rematch. Backend/Frontend/Architect reports **not trusted**.
Gate -1 in-process from `.aegis/governance/gates/gate_neg1_guardian_first.yaml`.
No USB GO. No commit. Never APPROVED. Not device-fixed. **PASS HOLD remains.**

Stamp: 2026-09-16T14:00:00Z

## Commands re-run

```
bash vendor/guardtalk/docs/qa/verify_remediate_b4_messenger_host.sh
→ PASS=33 FAIL=0 HOLD=4 EXIT=0

bash vendor/guardtalk/docs/qa/verify_remediate_b4_messenger_ux_host.sh
→ bash PASS=8 + python PASS=53 FAIL=0 HOLD=4 EXIT=0
```

Logs: `_artifacts/Q-REMEDIATE-B4-MESSENGER_BAKE.out`,
`_artifacts/Q-REMEDIATE-B4-MESSENGER_UX.out`

## Lunch (independent)

Session-only `GIT_CONFIG_COUNT=1` `safe.directory` = `vendor/adevtool`.
`set +u` around `envsetup`. Combo `komodo-trunk_staging-user`.

| Var | Value | Result |
|-----|-------|--------|
| TARGET_PRODUCT | komodo | PASS |
| TARGET_BUILD_VARIANT | user | PASS |
| GuardTalkMessenger in PRODUCT_PACKAGES | PRESENT | PASS |
| default-permissions-com.guardtalk.messenger | PRESENT | PASS |
| TrichromeChrome / AppStore | ABSENT | PASS |

## UX / protocol

| Check | Result |
|-------|--------|
| app_name GT Messenger | PASS |
| 9/9 default_workspace grids pin MessengerActivity | PASS (5x5 x=0 y=0; others x=1 y=0) |
| Messenger not in filtered_components items | PASS |
| first_run_hint + layout bind | PASS |
| unreachable copy distinct from unregistered | PASS |
| empty states need-gateway / need-register / empty | PASS |
| JSONRPC_PORT 8080 + path /jami/jsonrpc | PASS |
| JSON-RPC methods addAccount / getConversations / sendTextMessage | PASS (exactly those three) |
| RFC1918 vectors 14/14 + IPv6 fail-closed | PASS |
| no dl.jami.net / public DHT in app sources | PASS |
| adb devices | empty → jamid e2e HOLD |
| m GuardTalkMessenger | HOLD |
| pytest platform/tests | N/A (AOSP Kotlin / makefiles) |
