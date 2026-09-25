# Seizure check-in (12 h) — device client + Tor admin contract

**Task:** `T-REMEDIATE-B4-CHECKIN` (item 20)  
**Status:** host-static REVIEW; not device-fixed; Tor admin visibility **HOLD**  
**Date:** 2026-09-16

## Purpose

A seized or powered-off GuardTalkOS device stops sending a heartbeat. The
**Tor admin console** treats a missed 12-hour check-in (plus 1 hour grace) as
**overdue**. This tree ships the **device client** and the **payload/contract**.
It does **not** ship a Gateway or Tor admin service.

## What this tree contains

| Piece | Path |
|-------|------|
| Device app | `vendor/guardtalk/apps/GuardTalkCheckin/` |
| Host contract + pytest | `vendor/guardtalk/checkin/host/` |
| JSON Schema | `vendor/guardtalk/checkin/payload.schema.json` |
| Product wiring | `vendor/guardtalk/checkin/guardtalk-checkin.mk` |

## What this tree does **not** contain (HOLD)

- Gateway daemon / Tor daemon / onion private key
- Tor admin HTTP UI
- Any live `.onion` address
- Public-internet C2 URL

`Q-REMEDIATE-B4-CHECKIN` “visible in Tor admin” stays **HOLD** until a Gateway
that speaks this contract exists **outside** this GrapheneOS worktree (or is
later vendored). Do not invent a public C2 to close that HOLD.

## Interval

- Device JobScheduler periodic period: **12 hours** (`43_200_000` ms)
- Contract field `interval_s`: **43200**
- Tor admin overdue after: `interval_s + grace_s` (`43200 + 3600`)

First boot also enqueues a one-shot attempt with a 15-minute deadline so the
first heartbeat is not delayed a full interval.

## Transport (fail-closed, no public C2)

The client POSTs JSON only to a **provisioned** URL in
`Settings.Global["guardtalk_checkin_endpoint"]`.

| Endpoint class | Allowed | How it is sent |
|----------------|---------|----------------|
| Tor v3 onion (`56` base32 chars + `.onion`) | yes | SOCKS only (`guardtalk_checkin_socks`, loopback/RFC1918). **No clearnet fallback.** |
| RFC1918 / ULA / link-local / loopback | yes | Direct HTTP(S) on Gateway LAN |
| Public IPv4/IPv6, any non-onion DNS name | **rejected** | never sent |

Empty endpoint → local status `skipped_no_endpoint` (HOLD), nothing leaves the
device. Onion URL without SOCKS → `skipped_no_tor`, nothing leaves the device.

SOCKS default is **empty** (not `127.0.0.1:9050` baked in). Gateway/Orbot
provision writes `host:port` when Tor is actually present.

## Provisioning keys (no secrets in git)

Written by Gateway or a future signed QR field — **not** compiled into the APK:

| `Settings.Global` key | Value |
|-----------------------|--------|
| `guardtalk_checkin_endpoint` | `http(s)://<v3onion>/v1/checkin` **or** `http(s)://<RFC1918>/v1/checkin` |
| `guardtalk_checkin_socks` | `127.0.0.1:9050` style, LAN/loopback only |
| `guardtalk_checkin_device_id` | 32–64 lowercase hex opaque id |

If `device_id` is unset, the client derives SHA-256(`gtcid:` + `ANDROID_ID`)
hex (64 chars). It never sends IMEI, serial, phone number, SSID, location, or
tokens.

## HTTP contract (Tor admin / Gateway)

```
POST /v1/checkin
Content-Type: application/json; charset=utf-8
Accept: application/json
```

Redirects are **disabled**. 2xx = accepted. Schema:
`vendor/guardtalk/checkin/payload.schema.json`.

Example body (illustrative ids only):

```json
{
  "schema": "guardtalk.checkin.v1",
  "interval_s": 43200,
  "grace_s": 3600,
  "sent_at_unix": 1700000000,
  "seq": 3,
  "device_id": "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa",
  "status": "ok"
}
```

### Tor admin row

| Field | Rule |
|-------|------|
| `admin_surface` | `tor` only (non-Tor admin is forbidden) |
| `last_seen_unix` | time of last **accepted** `status=ok` |
| `state` | `ok` if age ≤ 46800 s; `overdue` if older; `never` if no check-in |

Gateway maps accepted POSTs onto that row. This worktree does not implement
that mapper.

## Local UI

`GT Check-in` shows last **status class**, last timestamp, and whether an
endpoint is configured (onion / gateway_lan / none). It does **not** display
the onion URL (seizer-visible).

## Tests

```bash
python3 -m unittest discover -s vendor/guardtalk/checkin/host -p 'test_*.py' -v
bash vendor/guardtalk/checkin/host/verify_host.sh
```

On-device JobScheduler + Tor admin live view: **HOLD** (`adb` empty / Gateway
absent).
