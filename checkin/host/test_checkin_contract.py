"""Host tests for T-REMEDIATE-B4-CHECKIN contract (item 20).

stdlib unittest so host verify does not need pytest (Law 22).
"""

from __future__ import annotations

import json
import sys
import unittest
from pathlib import Path

HOST_DIR = Path(__file__).resolve().parent
sys.path.insert(0, str(HOST_DIR))

from checkin_contract import (  # noqa: E402
    FORBIDDEN_PAYLOAD_KEYS,
    GRACE_S,
    INTERVAL_S,
    SCHEMA_ID,
    EndpointError,
    build_payload,
    decide_transport,
    tor_admin_row,
    validate_endpoint,
    validate_socks,
)

# RFC 7686 / Tor v3 example label (not a live service; tests only).
_ONION = "abcdefghijklmnopqrstuvwxyz234567abcdefghijklmnopqrstuvwx.onion"


class IntervalTests(unittest.TestCase):
    def test_interval_is_twelve_hours(self) -> None:
        self.assertEqual(INTERVAL_S, 12 * 60 * 60)
        self.assertEqual(INTERVAL_S, 43200)


class EndpointTests(unittest.TestCase):
    def test_accept_v3_onion_http(self) -> None:
        got = validate_endpoint(f"http://{_ONION}/v1/checkin")
        self.assertEqual(got["kind"], "onion")
        self.assertEqual(got["path"], "/v1/checkin")

    def test_accept_v3_onion_https(self) -> None:
        got = validate_endpoint(f"https://{_ONION}/v1/checkin")
        self.assertEqual(got["kind"], "onion")

    def test_reject_onion_v2(self) -> None:
        with self.assertRaises(EndpointError):
            validate_endpoint("http://abcdefghijklmnop.onion/v1/checkin")

    def test_accept_rfc1918(self) -> None:
        for url in (
            "http://10.1.2.3/v1/checkin",
            "http://192.168.1.1:8080/v1/checkin",
            "http://172.16.0.1/v1/checkin",
            "http://127.0.0.1/v1/checkin",
            "http://[fd12:3456::1]/v1/checkin",
        ):
            self.assertEqual(validate_endpoint(url)["kind"], "gateway_lan", url)

    def test_reject_public_c2(self) -> None:
        for url in (
            "https://example.com/v1/checkin",
            "http://8.8.8.8/v1/checkin",
            "https://1.1.1.1/checkin",
            "http://guardtalk.io/checkin",
            "https://api.github.com/checkin",
            "http://172.32.0.1/v1/checkin",
        ):
            with self.assertRaises(EndpointError):
                validate_endpoint(url)

    def test_reject_userinfo_and_bad_scheme(self) -> None:
        with self.assertRaises(EndpointError):
            validate_endpoint(f"http://user:pass@{_ONION}/v1/checkin")
        with self.assertRaises(EndpointError):
            validate_endpoint(f"ftp://{_ONION}/v1/checkin")
        with self.assertRaises(EndpointError):
            validate_endpoint("")

    def test_onion_requires_socks_no_clearnet_fallback(self) -> None:
        ep = validate_endpoint(f"http://{_ONION}/v1/checkin")
        with self.assertRaises(EndpointError):
            decide_transport(ep, "")
        self.assertEqual(decide_transport(ep, "127.0.0.1:9050"), "socks")

    def test_gateway_lan_direct(self) -> None:
        ep = validate_endpoint("http://192.168.0.1/v1/checkin")
        self.assertEqual(decide_transport(ep, ""), "direct")

    def test_socks_rejects_public_host(self) -> None:
        with self.assertRaises(EndpointError):
            validate_socks("8.8.8.8:9050")
        host, port = validate_socks("127.0.0.1:9050")
        self.assertEqual(host, "127.0.0.1")
        self.assertEqual(port, 9050)


class PayloadTests(unittest.TestCase):
    def test_payload_shape_and_no_pii_keys(self) -> None:
        body = build_payload(
            device_id="ab" * 16,
            sent_at_unix=1_700_000_000,
            seq=3,
            status="ok",
        )
        self.assertEqual(body["schema"], SCHEMA_ID)
        self.assertEqual(body["interval_s"], 43200)
        self.assertEqual(body["grace_s"], GRACE_S)
        self.assertTrue(FORBIDDEN_PAYLOAD_KEYS.isdisjoint(body.keys()))
        encoded = json.dumps(body)
        for token in ("imei", "serial", "latitude", "password", "token"):
            self.assertNotIn(token, encoded)

    def test_payload_rejects_non_opaque_id(self) -> None:
        with self.assertRaises(ValueError):
            build_payload("SERIAL123", 1, 0)
        with self.assertRaises(ValueError):
            build_payload("xyz", 1, 0)


class TorAdminTests(unittest.TestCase):
    def test_tor_admin_overdue_contract(self) -> None:
        now = 2_000_000_000
        ok = tor_admin_row(now - 1000, now)
        self.assertEqual(ok["state"], "ok")
        self.assertEqual(ok["admin_surface"], "tor")
        overdue = tor_admin_row(now - (INTERVAL_S + GRACE_S + 1), now)
        self.assertEqual(overdue["state"], "overdue")
        never = tor_admin_row(0, now)
        self.assertEqual(never["state"], "never")


if __name__ == "__main__":
    unittest.main()
