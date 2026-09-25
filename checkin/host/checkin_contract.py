"""Host-side seizure check-in contract (T-REMEDIATE-B4-CHECKIN, item 20).

Kotlin in vendor/guardtalk/apps/GuardTalkCheckin must stay in lockstep with
this module. Host pytest is the oracle; Android m is HOLD this card.

Fail-closed: no public-internet C2. Allowed endpoints are v3 onion (via
loopback/RFC1918 SOCKS only) or RFC1918/ULA/link-local/loopback HTTP(S).
No secrets belong in this tree.
"""

from __future__ import annotations

import ipaddress
import json
import re
from typing import Any
from urllib.parse import urlparse

SCHEMA_ID = "guardtalk.checkin.v1"
INTERVAL_S = 12 * 60 * 60  # 12 hours
GRACE_S = 60 * 60  # 1 hour overdue slack for Tor admin
MAX_URL_LEN = 512
MAX_BODY_LEN = 2048
DEFAULT_PATH = "/v1/checkin"
ONION_V3 = re.compile(r"^[a-z2-7]{56}\.onion$")
SOCKS_RE = re.compile(r"^([^:]+):(\d{1,5})$")

ALLOWED_SCHEMES = frozenset({"http", "https"})
FORBIDDEN_PAYLOAD_KEYS = frozenset(
    {
        "imei",
        "meid",
        "serial",
        "phone",
        "msisdn",
        "imsi",
        "latitude",
        "longitude",
        "ssid",
        "password",
        "token",
        "secret",
        "private_key",
    }
)


class EndpointError(ValueError):
    """Endpoint rejected by the fail-closed allowlist."""


def classify_host(host: str) -> str:
    """Return 'onion' | 'gateway_lan' or raise EndpointError."""
    raw = (host or "").strip().lower()
    if not raw:
        raise EndpointError("empty host")
    if raw.startswith("[") and raw.endswith("]"):
        raw = raw[1:-1]
    if ONION_V3.fullmatch(raw):
        return "onion"
    if raw in ("localhost",):
        return "gateway_lan"
    try:
        addr = ipaddress.ip_address(raw)
    except ValueError as exc:
        raise EndpointError("non-onion hostname rejected (no public DNS C2)") from exc
    if _is_gateway_lan(addr):
        return "gateway_lan"
    raise EndpointError("public IP rejected (no public-internet C2)")


def _is_gateway_lan(addr: ipaddress.IPv4Address | ipaddress.IPv6Address) -> bool:
    return bool(
        addr.is_private
        or addr.is_loopback
        or addr.is_link_local
    )


def validate_endpoint(url: str) -> dict[str, str]:
    """Parse and allowlist a check-in URL. Never returns a public C2."""
    text = (url or "").strip()
    if not text:
        raise EndpointError("empty endpoint")
    if len(text) > MAX_URL_LEN:
        raise EndpointError("endpoint too long")
    parsed = urlparse(text)
    if parsed.scheme not in ALLOWED_SCHEMES:
        raise EndpointError("scheme must be http or https")
    if parsed.username or parsed.password:
        raise EndpointError("userinfo rejected")
    if not parsed.hostname:
        raise EndpointError("missing host")
    kind = classify_host(parsed.hostname)
    path = parsed.path or DEFAULT_PATH
    return {
        "kind": kind,
        "scheme": parsed.scheme,
        "host": parsed.hostname.lower(),
        "path": path,
        "url": text,
    }


def validate_socks(spec: str) -> tuple[str, int]:
    """Allow SOCKS only on loopback/RFC1918 (Tor on Gateway or device)."""
    text = (spec or "").strip()
    match = SOCKS_RE.fullmatch(text)
    if not match:
        raise EndpointError("socks must be host:port")
    host, port_s = match.group(1), match.group(2)
    port = int(port_s)
    if port < 1 or port > 65535:
        raise EndpointError("socks port out of range")
    kind = classify_host(host)
    if kind != "gateway_lan":
        raise EndpointError("socks host must be loopback or RFC1918/ULA")
    return host, port


def build_payload(
    device_id: str,
    sent_at_unix: int,
    seq: int,
    status: str = "ok",
) -> dict[str, Any]:
    """Build the v1 JSON object posted to Tor admin / Gateway."""
    did = (device_id or "").strip()
    if not re.fullmatch(r"[a-f0-9]{32,64}", did):
        raise ValueError("device_id must be 32-64 lowercase hex (opaque)")
    if seq < 0:
        raise ValueError("seq must be >= 0")
    if sent_at_unix < 0:
        raise ValueError("sent_at_unix must be >= 0")
    body = {
        "schema": SCHEMA_ID,
        "interval_s": INTERVAL_S,
        "grace_s": GRACE_S,
        "sent_at_unix": int(sent_at_unix),
        "seq": int(seq),
        "device_id": did,
        "status": status,
    }
    leaked = FORBIDDEN_PAYLOAD_KEYS.intersection(body.keys())
    if leaked:
        raise ValueError(f"forbidden payload keys: {sorted(leaked)}")
    encoded = json.dumps(body, separators=(",", ":"), sort_keys=True)
    if len(encoded) > MAX_BODY_LEN:
        raise ValueError("payload too large")
    return body


def tor_admin_row(last_seen_unix: int, now_unix: int) -> dict[str, Any]:
    """Tor admin visibility contract: overdue when last seen exceeds 12h+grace."""
    age = now_unix - last_seen_unix
    overdue_after = INTERVAL_S + GRACE_S
    if last_seen_unix <= 0:
        state = "never"
    elif age > overdue_after:
        state = "overdue"
    else:
        state = "ok"
    return {
        "last_seen_unix": last_seen_unix,
        "age_s": age,
        "overdue_after_s": overdue_after,
        "state": state,
        "admin_surface": "tor",
    }


def decide_transport(endpoint: dict[str, str], socks_spec: str) -> str:
    """Return 'socks' | 'direct' or raise EndpointError.

    Onion never falls back to clearnet. Missing SOCKS is a skip, not a send.
    """
    if endpoint["kind"] == "onion":
        if not (socks_spec or "").strip():
            raise EndpointError("onion requires SOCKS (no clearnet fallback)")
        validate_socks(socks_spec)
        return "socks"
    return "direct"
