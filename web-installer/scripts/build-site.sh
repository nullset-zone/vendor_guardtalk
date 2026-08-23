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

# Tokens from the wizard sheet + route rules (style-src 'self').
cat wizard/styles.css routes/install/styles-route.css > "$SITE/install/styles-route.css"

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
