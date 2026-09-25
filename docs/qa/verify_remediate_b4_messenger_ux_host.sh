#!/usr/bin/env bash
# Independent rematch for Q-REMEDIATE-B4-MESSENGER item 19 client UX.
# Pair of F-REMEDIATE-B4-MESSENGER (+ T bake claims rematched in
# verify_remediate_b4_messenger_host.sh). Do not trust Frontend/Backend reports.
# Host static only. jamid e2e / m / device HOLD. Not device-fixed.
# Never APPROVED. No USB GO. No commit. Do not lift PASS HOLD.
#
# Usage (from GrapheneOS-worktree root):
#   bash vendor/guardtalk/docs/qa/verify_remediate_b4_messenger_ux_host.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/../../../.." && pwd)"
cd "$ROOT"

FAIL=0
PASS_N=0
HOLD_N=0
pass() { echo "PASS: $*"; PASS_N=$((PASS_N + 1)); }
fail() { echo "FAIL: $*"; FAIL=$((FAIL + 1)); }
hold() { echo "HOLD: $*"; HOLD_N=$((HOLD_N + 1)); }

STRINGS="vendor/guardtalk/apps/GuardTalkMessenger/res/values/strings.xml"
LAYOUT="vendor/guardtalk/apps/GuardTalkMessenger/res/layout/activity_messenger.xml"
ACT="vendor/guardtalk/apps/GuardTalkMessenger/src/com/guardtalk/messenger/MessengerActivity.kt"
RPC="vendor/guardtalk/apps/GuardTalkMessenger/src/com/guardtalk/messenger/JamiGatewayClient.kt"
GW="vendor/guardtalk/apps/GuardTalkMessenger/src/com/guardtalk/messenger/GatewayEndpoint.kt"
MAN="vendor/guardtalk/apps/GuardTalkMessenger/AndroidManifest.xml"
OVL_CFG="vendor/guardtalk/overlays/GuardTalkLauncherOverlay/res/values/config.xml"
WS_DIR="vendor/guardtalk/overlays/GuardTalkLauncherOverlay/res/xml"

require_file() {
  local f="$1"
  if [[ -f "$f" ]]; then
    pass "present: $f"
  else
    fail "missing: $f"
  fi
}

echo "=== Q-REMEDIATE-B4-MESSENGER UX rematch (item 19) ==="
echo "ROOT=$ROOT"
echo "LIVE_DEVICE_CLAIMED=false"
echo "F/Backend reports: not trusted"
echo "USB_GO=not started"
echo

echo "--- required UX files ---"
require_file "$STRINGS"
require_file "$LAYOUT"
require_file "$ACT"
require_file "$RPC"
require_file "$GW"
require_file "$MAN"
require_file "$OVL_CFG"

echo
echo "--- python UX + protocol rematch ---"
python3 - <<'PY'
import ipaddress
import pathlib
import re
import sys
import xml.etree.ElementTree as ET

root = pathlib.Path(".")
fail = 0
pass_n = 0
hold_n = 0


def out(kind, msg):
    global fail, pass_n, hold_n
    print(f"{kind}: {msg}")
    if kind == "PASS":
        pass_n += 1
    elif kind == "FAIL":
        fail += 1
    else:
        hold_n += 1


def read(p):
    return (root / p).read_text(encoding="utf-8", errors="replace")


def parse_strings(text):
    found = {}
    for m in re.finditer(
        r'<string\s+name="([^"]+)">([^<]*)</string>', text
    ):
        found[m.group(1)] = m.group(2)
    return found


APP = "vendor/guardtalk/apps/GuardTalkMessenger"
STRINGS = f"{APP}/res/values/strings.xml"
LAYOUT = f"{APP}/res/layout/activity_messenger.xml"
ACT = f"{APP}/src/com/guardtalk/messenger/MessengerActivity.kt"
RPC = f"{APP}/src/com/guardtalk/messenger/JamiGatewayClient.kt"
GW = f"{APP}/src/com/guardtalk/messenger/GatewayEndpoint.kt"
MAN = f"{APP}/AndroidManifest.xml"
OVL_CFG = "vendor/guardtalk/overlays/GuardTalkLauncherOverlay/res/values/config.xml"
WS_DIR = pathlib.Path(
    "vendor/guardtalk/overlays/GuardTalkLauncherOverlay/res/xml"
)

strings = parse_strings(read(STRINGS))
layout = read(LAYOUT)
act = read(ACT)
rpc = read(RPC)
gw = read(GW)
man = read(MAN)
ovl = read(OVL_CFG)

# --- launcher label ---
if strings.get("app_name") == "GT Messenger":
    out("PASS", "app_name is GT Messenger")
else:
    out("FAIL", f"app_name={strings.get('app_name')!r} (expected 'GT Messenger')")

if 'android:label="@string/app_name"' in man:
    out("PASS", "manifest launcher label uses @string/app_name")
else:
    out("FAIL", "manifest missing android:label=@string/app_name")

# --- first-run hint ---
hint = strings.get("first_run_hint", "")
if hint and "Gateway" in hint and "Off the LAN" in hint:
    out("PASS", "first_run_hint present (Gateway + off-LAN)")
else:
    out("FAIL", "first_run_hint missing Gateway/off-LAN copy")

if 'android:id="@+id/first_run_hint"' in layout and (
    'android:text="@string/first_run_hint"' in layout
):
    out("PASS", "layout binds first_run_hint")
else:
    out("FAIL", "layout missing first_run_hint id/text")

# --- unreachable vs unregistered ---
unreg = strings.get("status_unregistered", "")
unreach = strings.get("err_gateway_unreachable", "")
nowifi = strings.get("status_no_wifi", "")
notpriv = strings.get("status_not_private", "")
timeout = strings.get("err_gateway_timeout", "")
if unreg and unreach and unreg != unreach:
    out("PASS", "unreachable copy distinct from unregistered")
else:
    out("FAIL", "unreachable/unregistered copy missing or identical")

if nowifi and unreg and nowifi != unreg:
    out("PASS", "no-Wi-Fi copy distinct from unregistered")
else:
    out("FAIL", "no-Wi-Fi copy missing or collides with unregistered")

if notpriv and "RFC1918" in notpriv and "Public Jami is not used" in notpriv:
    out("PASS", "not-RFC1918 copy fail-closed (no public Jami)")
else:
    out("FAIL", "status_not_private missing RFC1918/public-Jami copy")

if "8080" in unreach and "jamid" in unreach:
    out("PASS", "unreachable copy names port 8080 + jamid")
else:
    out("FAIL", "err_gateway_unreachable missing 8080/jamid")

if timeout and timeout != unreg:
    out("PASS", "timeout copy distinct from unregistered")
else:
    out("FAIL", "timeout copy missing or collides with unregistered")

# Activity must not toast bind-fail as unregistered
if "bindFailureCopy" in act and "R.string.status_unregistered" in act:
    bind_fn = act.split("fun bindFailureCopy()", 1)[-1].split("fun ", 1)[0]
    if "status_unregistered" in bind_fn:
        out("FAIL", "bindFailureCopy uses status_unregistered")
    else:
        out("PASS", "bindFailureCopy does not use unregistered copy")
else:
    out("FAIL", "bindFailureCopy missing or status_unregistered unused")

if "ERR_UNREACHABLE" in act and "err_gateway_unreachable" in act:
    out("PASS", "mapRpcError maps unreachable token to err_gateway_unreachable")
else:
    out("FAIL", "Activity does not map ERR_UNREACHABLE to err_gateway_unreachable")

# --- empty states ---
for key in ("log_need_gateway", "log_need_register", "log_empty"):
    val = strings.get(key, "")
    if val and "No conversations" in val:
        out("PASS", f"empty state {key}")
    else:
        out("FAIL", f"empty state {key} missing")

if "R.string.log_need_gateway" in act and "R.string.log_need_register" in act:
    if "R.string.log_empty" in act:
        out("PASS", "Activity paints three empty-state strings")
    else:
        out("FAIL", "Activity missing log_empty")
else:
    out("FAIL", "Activity missing need-gateway/need-register empty states")

if 'android:text="@string/log_need_gateway"' in layout:
    out("PASS", "layout default empty state is need-gateway")
else:
    out("FAIL", "layout default log_text is not log_need_gateway")

# --- RFC1918 GatewayEndpoint ---
if re.search(r"JSONRPC_PORT:\s*Int\s*=\s*8080", gw):
    out("PASS", "GatewayEndpoint JSONRPC_PORT=8080")
else:
    out("FAIL", "GatewayEndpoint JSONRPC_PORT is not 8080")

if re.search(r'JSONRPC_PATH:\s*String\s*=\s*"/jami/jsonrpc"', gw):
    out("PASS", "GatewayEndpoint JSONRPC_PATH=/jami/jsonrpc")
else:
    out("FAIL", "GatewayEndpoint JSONRPC_PATH is not /jami/jsonrpc")

if "http://${addr.hostAddress}:$JSONRPC_PORT$JSONRPC_PATH" in gw:
    out("PASS", "URL built only from RFC1918 host + PORT + PATH")
else:
    out("FAIL", "GatewayEndpoint URL template changed")

if "fun isRfc1918" in gw and "a0 == 10" in gw and "a0 == 192 && a1 == 168" in gw:
    if "a0 == 172 && a1 in 16..31" in gw:
        out("PASS", "isRfc1918 covers 10/8, 192.168/16, 172.16/12")
    else:
        out("FAIL", "isRfc1918 missing 172.16/12")
else:
    out("FAIL", "isRfc1918 ranges missing")

if "if (!isRfc1918(addr))" in gw and "return null" in gw:
    out("PASS", "resolve() fail-closed when not RFC1918")
else:
    out("FAIL", "resolve() does not fail-closed on non-RFC1918")

# Independent RFC1918 vector rematch of the Kotlin ranges
def is_rfc1918_bytes(b):
    if b is None or len(b) != 4:
        return False
    a0 = b[0] & 0xFF
    a1 = b[1] & 0xFF
    if a0 == 10:
        return True
    if a0 == 192 and a1 == 168:
        return True
    if a0 == 172 and 16 <= a1 <= 31:
        return True
    return False


vectors = [
    ("10.0.0.1", True),
    ("10.255.255.255", True),
    ("192.168.0.1", True),
    ("192.168.255.1", True),
    ("172.16.0.1", True),
    ("172.31.255.1", True),
    ("172.15.0.1", False),
    ("172.32.0.1", False),
    ("8.8.8.8", False),
    ("1.1.1.1", False),
    ("127.0.0.1", False),
    ("169.254.1.1", False),
    ("100.64.0.1", False),
    ("0.0.0.0", False),
]
vec_fail = 0
for addr, expect in vectors:
    got = is_rfc1918_bytes(ipaddress.ip_address(addr).packed)
    if got != expect:
        vec_fail += 1
        out("FAIL", f"RFC1918 vector {addr} got {got} expected {expect}")
if vec_fail == 0:
    out("PASS", f"RFC1918 vectors {len(vectors)}/{len(vectors)}")

# IPv6 is fail-closed (Kotlin rejects non-4-byte)
if is_rfc1918_bytes(ipaddress.ip_address("::1").packed) is False:
    out("PASS", "IPv6 fail-closed (non-IPv4 rejected)")
else:
    out("FAIL", "IPv6 unexpectedly accepted as RFC1918")

# --- JSON-RPC methods ---
methods = set(re.findall(r'call\("([A-Za-z]+)"', rpc))
expected = {"addAccount", "getConversations", "sendTextMessage"}
if methods == expected:
    out("PASS", "JSON-RPC methods exactly addAccount/getConversations/sendTextMessage")
elif expected.issubset(methods):
    extra = sorted(methods - expected)
    out("FAIL", f"JSON-RPC extra methods: {extra}")
else:
    out("FAIL", f"JSON-RPC methods={sorted(methods)} missing {sorted(expected - methods)}")

for name, fn in (
    ("addAccount", "fun addRingAccount"),
    ("getConversations", "fun listConversations"),
    ("sendTextMessage", "fun sendText"),
):
    if fn in rpc and f'call("{name}"' in rpc:
        out("PASS", f"wrapper still calls {name}")
    else:
        out("FAIL", f"wrapper missing {name}")

# --- no public DHT / dl.jami.net in app sources ---
app_files = list(pathlib.Path(APP).rglob("*"))
host_hits = []
forbid = re.compile(
    r"(dl\.jami\.net|bootstrap\.jami|jami\.net|opendht\.|public.?DHT)",
    re.I,
)
for p in app_files:
    if not p.is_file():
        continue
    if p.suffix.lower() not in {".kt", ".xml", ".bp", ".md", ".txt"}:
        continue
    text = p.read_text(encoding="utf-8", errors="replace")
    for m in forbid.finditer(text):
        token = m.group(0)
        # Allow explicit "Public Jami is not used" / comment deny language
        if token.lower() in {"jami.net", "public dht", "public?dht"}:
            snippet = text[max(0, m.start() - 40) : m.end() + 40]
            if re.search(r"not used|not\s+the public|rejected", snippet, re.I):
                continue
        host_hits.append(f"{p}:{token}")

if not host_hits:
    out("PASS", "app sources have no dl.jami.net / public DHT host")
else:
    out("FAIL", f"public Jami host hits: {host_hits[:8]}")

http_urls = re.findall(r'https?://[^\s"\'<>]+', gw + "\n" + rpc)
bad_urls = [
    u
    for u in http_urls
    if "JSONRPC" not in u and "rfc1918" not in u.lower() and "<" not in u
]
# GatewayEndpoint builds http://${addr...} — template only
template_ok = all(
    ("${addr" in u or "rfc1918" in u.lower() or "<rfc1918>" in u.lower())
    for u in http_urls
) or not http_urls
if template_ok and not any("jami.net" in u for u in http_urls):
    out("PASS", "no hardcoded public http(s) endpoint in Gateway/RPC")
else:
    out("FAIL", f"unexpected http(s) URLs: {http_urls}")

# --- overlay 9/9 workspace pins ---
NS = {"l": "http://schemas.android.com/apk/res-auto/com.android.launcher3"}
ws_files = sorted(WS_DIR.glob("default_workspace_*.xml"))
if len(ws_files) == 9:
    out("PASS", "exactly 9 default_workspace_*.xml grids")
else:
    out("FAIL", f"workspace grid count={len(ws_files)} (expected 9)")

expected_names = {
    "default_workspace_2x2.xml",
    "default_workspace_3x3.xml",
    "default_workspace_4x4.xml",
    "default_workspace_4x5.xml",
    "default_workspace_5x5.xml",
    "default_workspace_5x8.xml",
    "default_workspace_6x5.xml",
    "default_workspace_7x3.xml",
    "default_workspace_8x3.xml",
}
got_names = {p.name for p in ws_files}
if got_names == expected_names:
    out("PASS", "workspace filenames match 9 known launcher grids")
else:
    out("FAIL", f"unexpected workspace files: {sorted(got_names)}")

pin_fail = 0
for p in ws_files:
    tree = ET.parse(p)
    favs = tree.getroot().findall("favorite")
    messenger = [
        f
        for f in favs
        if f.get(f"{{{NS['l']}}}packageName") == "com.guardtalk.messenger"
        and f.get(f"{{{NS['l']}}}className")
        == "com.guardtalk.messenger.MessengerActivity"
    ]
    if len(messenger) != 1:
        pin_fail += 1
        out("FAIL", f"{p.name} messenger pin count={len(messenger)}")
        continue
    x = messenger[0].get(f"{{{NS['l']}}}x")
    y = messenger[0].get(f"{{{NS['l']}}}y")
    if p.name == "default_workspace_5x5.xml":
        expect_x, expect_y = "0", "0"
    else:
        expect_x, expect_y = "1", "0"
    if x == expect_x and y == expect_y:
        out("PASS", f"{p.name} pins MessengerActivity x={x} y={y}")
    else:
        pin_fail += 1
        out("FAIL", f"{p.name} pin at x={x} y={y} (expected {expect_x},{expect_y})")

    banned = []
    for f in favs:
        pkg = f.get(f"{{{NS['l']}}}packageName") or ""
        cls = f.get(f"{{{NS['l']}}}className") or ""
        blob = f"{pkg}/{cls}"
        if re.search(
            r"TrichromeChrome|AppStore|com\.android\.vending|org\.chromium",
            blob,
        ):
            banned.append(blob)
    if banned:
        pin_fail += 1
        out("FAIL", f"{p.name} pins browser/store: {banned}")
    else:
        out("PASS", f"{p.name} no TrichromeChrome/AppStore favorite")

if pin_fail == 0 and len(ws_files) == 9:
    out("PASS", "9/9 grids pin com.guardtalk.messenger/.MessengerActivity")

# filtered_components must not hide messenger
items = re.findall(r"<item>([^<]+)</item>", ovl)
if any("guardtalk.messenger" in i for i in items):
    out("FAIL", f"filtered_components hides messenger: {items}")
else:
    out("PASS", "Messenger absent from filtered_components items")

# --- fail-closed Activity wiring ---
if "BindState.NO_WIFI" in act and "BindState.NOT_PRIVATE" in act:
    out("PASS", "Activity BindState includes NO_WIFI and NOT_PRIVATE")
else:
    out("FAIL", "Activity missing NO_WIFI/NOT_PRIVATE bind states")

if "client = JamiGatewayClient(target.url)" in act:
    out("PASS", "RPC client constructed only after resolve() Target")
else:
    out("FAIL", "Activity client construction not gated on GatewayEndpoint")

print(f"PY_COUNTS PASS_COUNT={pass_n} FAIL_COUNT={fail} HOLD_COUNT={hold_n}")
sys.exit(1 if fail else 0)
PY
PY_RC=$?
if [[ "$PY_RC" -eq 0 ]]; then
  pass "python UX rematch exit 0"
else
  fail "python UX rematch exit $PY_RC"
fi

echo
echo "--- adb / jamid e2e (must HOLD if empty) ---"
ADB_OUT="$(adb devices 2>/dev/null || true)"
echo "$ADB_OUT"
if echo "$ADB_OUT" | awk 'NR>1 && NF && $1!="" {found=1} END{exit !found}'; then
  hold "adb device attached — jamid e2e still PASS HOLD (not this card; not device-fixed)"
else
  hold "adb devices empty — jamid e2e HOLD. Not device-fixed."
fi

hold "m GuardTalkMessenger not run (Soong compile HOLD)"
hold "Gateway jamid e2e HOLD (no USB GO; PASS HOLD remains)"
hold "never APPROVED; not live"

echo
echo "SUMMARY PASS=${PASS_N} FAIL=${FAIL} HOLD=${HOLD_N}"
if [[ "$FAIL" -ne 0 ]]; then
  echo "VERDICT FAIL"
  exit 1
fi
echo "VERDICT PASS (host-static UX; PASS HOLD remains)"
exit 0
