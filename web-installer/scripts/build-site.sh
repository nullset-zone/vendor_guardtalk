#!/usr/bin/env bash
# Emit the offline static site under dist/site (D-006, D-013).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

# Resolve the TypeScript compiler without assuming `npx` is on PATH (it is
# absent in some CI images and in this workspace). Prefer the local install.
if [[ -x "$ROOT/node_modules/typescript/bin/tsc" ]] && [[ -n "${NODE:-$(command -v node || true)}" ]]; then
  "${NODE:-node}" "$ROOT/node_modules/typescript/bin/tsc" -p tsconfig.routes.json
elif command -v npx >/dev/null 2>&1; then
  npx tsc -p tsconfig.routes.json
else
  echo "error: no TypeScript compiler available (need node + node_modules/typescript, or npx on PATH)" >&2
  exit 1
fi

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

# F-001 (OpenStateStack Foundation zero-key-custody alignment): drop unreferenced
# legacy modules from the emitted site (cli-export, user-anchor, and unused key-custody helpers).
rm -rf \
  "$SITE/lib/cli-export" \
  "$SITE/lib/verify/user-anchor.js" \
  "$SITE/lib/keys/export-enc.js" \
  "$SITE/lib/keys/import.js" \
  "$SITE/lib/keys/generate.js"
if [[ -f "$SITE/lib/verify/index.js" ]]; then
  grep -v '"./user-anchor.js"' "$SITE/lib/verify/index.js" > "$SITE/lib/verify/index.js.tmp"
  mv "$SITE/lib/verify/index.js.tmp" "$SITE/lib/verify/index.js"
fi
if [[ -e "$SITE/lib/cli-export/generator.js" ]] || [[ -e "$SITE/lib/verify/user-anchor.js" ]] \
  || [[ -e "$SITE/lib/keys/export-enc.js" ]] || [[ -e "$SITE/lib/keys/import.js" ]] \
  || [[ -e "$SITE/lib/keys/generate.js" ]]; then
  echo "error: legacy cli-export/user-anchor/key-custody modules leaked into $SITE/lib/" >&2
  exit 1
fi

# Install graph (same directory as index.html so ./install-app.js resolves).
cp dist/routes-js/routes/install/*.js "$SITE/install/"
cp routes/install/page.html "$SITE/install/index.html"

# Sibling routes import lib two levels up from their own source depth, so their
# compiled modules must sit one directory below lib/ in the emitted site.
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

# Root index points at /wizard/ without a network fetch.
cat > "$SITE/index.html" <<'EOF'
<!DOCTYPE html>
<html lang="en">
  <head>
    <meta charset="utf-8" />
    <meta http-equiv="refresh" content="0; url=./wizard/" />
    <title>GuardTalkOS installer</title>
    <meta http-equiv="Content-Security-Policy"
          content="default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'" />
  </head>
  <body>
    <p><a href="./wizard/">Open the installer</a></p>
  </body>
</html>
EOF

echo "site written to $SITE"
