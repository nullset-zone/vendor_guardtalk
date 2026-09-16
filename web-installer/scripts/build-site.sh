#!/usr/bin/env bash
# Emit the offline static site under dist/site (D-006, D-013).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

npx tsc -p tsconfig.routes.json

SITE="$ROOT/dist/site"
rm -rf "$SITE"
mkdir -p \
  "$SITE/lib" \
  "$SITE/src" \
  "$SITE/install/update" \
  "$SITE/install/verify-device" \
  "$SITE/install/recover" \
  "$SITE/threat-model"

cp -a dist/routes-js/lib/. "$SITE/lib/"
cp -a dist/routes-js/src/. "$SITE/src/"

# Install graph (same directory as index.html so ./install-app.js resolves).
cp dist/routes-js/routes/install/*.js "$SITE/install/"
cp routes/install/page.html "$SITE/install/index.html"

# Sibling routes keep ../../lib from their source depth.
cp dist/routes-js/routes/update/*.js "$SITE/install/update/"
cp routes/update/page.html "$SITE/install/update/index.html"

cp dist/routes-js/routes/verify-device/*.js "$SITE/install/verify-device/"
cp routes/verify-device/page.html "$SITE/install/verify-device/index.html"

cp dist/routes-js/routes/recover/*.js "$SITE/install/recover/"
cp routes/recover/page.html "$SITE/install/recover/index.html"

cp routes/threat-model/page.html "$SITE/threat-model/index.html"

# Pajamas vendor tree is required at build time (DEC-WEBINSTALL-010).
# Concatenate --gl-* tokens + reset + template/component CSS into the
# same-origin stylesheet already linked by every route (style-src 'self').
# reset.css is included so route HTML matches published Pajamas chrome
# (D-006: no remote fonts — reset names system-ui / ui-monospace only).
PAJAMAS="$ROOT/design/pajamas"
VENDOR_TOKENS="$PAJAMAS/tokens.css"
VENDOR_RESET="$PAJAMAS/reset.css"
VENDOR_TEMPLATES="$PAJAMAS/templates.css"
VENDOR_COMPONENTS="$PAJAMAS/components.css"
if [[ ! -d "$PAJAMAS" ]]; then
  echo "error: missing Pajamas vendor tree: $PAJAMAS" >&2
  exit 1
fi
for _pajama_file in "$VENDOR_TOKENS" "$VENDOR_RESET" "$VENDOR_TEMPLATES" "$VENDOR_COMPONENTS"; do
  if [[ ! -s "$_pajama_file" ]]; then
    echo "error: missing or empty Pajamas vendor file: $_pajama_file" >&2
    exit 1
  fi
done
if ! grep -q -- '--gl-' "$VENDOR_TOKENS"; then
  echo "error: $VENDOR_TOKENS has no --gl-* tokens" >&2
  exit 1
fi

cat \
  "$VENDOR_TOKENS" \
  "$VENDOR_RESET" \
  "$VENDOR_TEMPLATES" \
  "$VENDOR_COMPONENTS" \
  wizard/styles.css \
  routes/install/styles-route.css \
  > "$SITE/install/styles-route.css"

if grep -E -n 'design\.guardtalk\.io|@import url\(http|fonts\.googleapis' \
  "$SITE/install/styles-route.css"; then
  echo "error: emitted styles-route.css contains a remote stylesheet/font reference" >&2
  exit 1
fi

# Root index points at /install without a network fetch.
cat > "$SITE/index.html" <<'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta http-equiv="refresh" content="0; url=./install/" />
    <title>GuardTalkOS installer</title>
    <meta http-equiv="Content-Security-Policy"
          content="default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'none'" />
  </head>
  <body>
    <p><a href="./install/">Open the installer</a></p>
  </body>
</html>
EOF

echo "site written to $SITE"
