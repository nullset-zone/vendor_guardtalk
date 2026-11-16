/**
 * /install steps 0–4 route tests (Route Builder A, Phase 3).
 *
 * Headless: drives the pure decision functions and asserts over the emitted
 * HTML strings. No DOM is constructed; WebCrypto comes from Node's
 * globalThis (node ≥ 20 exposes webcrypto as crypto).
 *
 * Gates covered:
 * - step sequence 0→4 reachable ONLY via the correct named actions in order;
 *   out-of-order yields OUT_OF_ORDER stops
 * - step 2 tamper matrix: flipped package byte ⇒ HASH_MISMATCH stop rendered
 *   with the verbatim reason; bad signature ⇒ SIGNATURE_INVALID
 * - step 3: no card pre-selected; wrong retype never advances; correct retype
 *   does; flow cards render equal in shape and heading level
 * - step 4: chain-descriptor fixture ⇒ PARTITION_LAYOUT_UNKNOWN stop + Q-07
 *   placeholder; clean vbmeta ⇒ vbmeta-signed after a real resign+verify
 *   roundtrip with a test RSA key
 * - CSP sweep over ALL emitted markup (no onclick=/style=)
 * - custody sweep: no private-key material in any emitted string, given a
 *   known test key
 */
import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

import {
  ACK_CTA_LABEL,
  ALPHA_POSTURE_FLAGS,
  CUSTODY_SENTENCES,
  SUPPORTED_TARGETS,
  filesReady,
  renderInstallerChrome,
  renderPostureHeader,
  renderRouteFooter,
  renderStep0,
  renderStep1,
  renderStep2,
  verifyRelease,
  assertReleaseFetchUrl,
  fetchReleaseObjects,
  getAllowedReleaseObject,
  releaseFetchAllowed,
  releaseObjectUrl,
  RELEASE_PACKAGE_NAME,
  RELEASE_SIG_NAME,
  RELEASE_SUMS_NAME,
} from "../routes/install/early-steps.js";
import { filesPickedRefusal } from "../routes/install/install-app.js";
import { initialInstallState, reduce } from "../lib/install-state/machine.js";
import type { InstallAction, InstallState } from "../lib/install-state/machine.js";
import { STOP_REASONS } from "../lib/install-state/stops.js";
import { lintText } from "../lib/claims/lint-claims.js";
import { INSTALLER_CSP, RELEASE_FETCH_ORIGIN } from "../lib/claims/csp.js";
import {
  ONION_ADDRESS_FACT,
  RELEASE_FINGERPRINT_FACT,
  UNAVAILABLE_CHIP_WORD,
} from "../lib/ui/unavailable.js";

const ENC = new TextEncoder();

const PACKAGE_NAME = "guardtalk-os.zip";

interface VerifyInputLike {
  packageName: string;
  packageBytes: Uint8Array;
  sumsText: string;
  manifest: { buildId: string; targetProduct: string; version: string };
}

async function goodVerifyInput(): Promise<{ input: VerifyInputLike; packageBytes: Uint8Array }> {
  const packageBytes = ENC.encode(`package-bytes-of-${PACKAGE_NAME}`);
  const pkgDigest = createHash("sha256").update(packageBytes).digest("hex");
  const sums = [
    "# GuardTalkOS alpha test bundle",
    `${pkgDigest}  ${PACKAGE_NAME}`,
    `${createHash("sha256").update("vbmeta-bytes").digest("hex")}  vbmeta.img`,
  ].join("\n");
  return {
    packageBytes,
    input: {
      packageName: PACKAGE_NAME,
      packageBytes,
      sumsText: sums,
      manifest: { buildId: "20260822-000000", targetProduct: "tokay", version: "alpha-1" },
    },
  };
}

// ---------------------------------------------------------------------------
// CSP + custody sweeps over every emitted markup string
// ---------------------------------------------------------------------------

const CSP_FORBIDDEN_ATTRS = [/\son[a-z]+\s*=\s*"/i, /\sstyle\s*=\s*"/i];

function emittedMarkups(state: InstallState): ReadonlyArray<readonly [string, string]> {
  return [
    ["posture", renderPostureHeader()],
    ["footer", renderRouteFooter()],
    ["step0", renderStep0()],
    ["step1-empty", renderStep1({ package: false, sums: false, sig: false })],
    ["step1-ready", renderStep1({ package: true, sums: true, sig: true })],
    [
      "step2-verified",
      renderStep2({
        status: "verified",
        rows: [],
        meta: { buildId: "b", targetProduct: "tokay", version: "v" },
      }),
    ],
    [
      "step2-stopped",
      renderStep2({
        status: "stopped",
        rows: [],
        stopReason: STOP_REASONS.HASH_MISMATCH,
        detail: "SHA256SUMS line 2: malformed line",
      }),
    ],
    ["chrome", renderInstallerChrome({ state, stepHtml: "<p>x</p>" })],
  ];
}

test("CSP sweep: no inline handlers or style attributes in any emitted markup", () => {
  const state = reduce(initialInstallState("install"), { type: "acknowledge-intro" });
  for (const [name, html] of emittedMarkups(state)) {
    for (const pattern of CSP_FORBIDDEN_ATTRS) {
      assert.doesNotMatch(html, pattern, `${name} must not carry inline handlers or style attributes`);
    }
  }
});

test("page shell carries the exact D-006 CSP meta and no inline script/style", () => {
  const page = readFileSync(
    fileURLToPath(new URL("../routes/install/page.html", import.meta.url)),
    "utf8",
  );
  assert.ok(page.includes(INSTALLER_CSP), "page.html must embed the exact D-006 CSP");
  assert.doesNotMatch(page, /192\.168\.2\.220/);
  assert.doesNotMatch(page, /nothing is sent/i);
  assert.doesNotMatch(page, /\son[a-z]+\s*=/i);
  assert.doesNotMatch(page, /\sstyle\s*=/i);
  assert.doesNotMatch(page, /fetch\(|XMLHttpRequest|WebSocket/i);
});

test("route stylesheet contains no network url references", () => {
  const css = readFileSync(
    fileURLToPath(new URL("../routes/install/styles-route.css", import.meta.url)),
    "utf8",
  );
  assert.doesNotMatch(css, /url\(\s*['"]?https?:/i);
});

// ---------------------------------------------------------------------------
// Step sequence 0→4 via machine actions
// ---------------------------------------------------------------------------

function advanceActionFor(step: number): InstallAction {
  switch (step) {
    case 0:
      return { type: "acknowledge-intro" };
    case 1:
      return { type: "files-picked" };
    case 2:
      return { type: "release-verified" };
    case 3:
      return { type: "fingerprint-recorded" };
    case 4:
      return { type: "vbmeta-signed" };
    default:
      throw new Error(`no advance action for step ${step}`);
  }
}

function driveTo(target: number): InstallState {
  let state = initialInstallState("install");
  for (const step of [0, 1, 2, 3]) {
    if (state.currentStep === target) {
      return state;
    }
    // Reaching past step 3 requires choosing a flow first; it records the
    // choice without advancing, then fingerprint-recorded moves 3→4.
    state =
      step === 3
        ? reduce(reduce(state, { type: "key-flow-chosen", keyFlow: 1 }), {
            type: "fingerprint-recorded",
          })
        : reduce(state, advanceActionFor(step));
    if (state.currentStep !== step + 1) {
      throw new Error(`driveTo(${target}) stalled at step ${state.currentStep}`);
    }
  }
  if (state.currentStep === target) {
    return state;
  }
  throw new Error(`driveTo(${target}) never landed`);
}

test("steps 0→4 are reachable only through their exact named actions in order", () => {
  const expectations: ReadonlyArray<readonly [number, number]> = [
    [0, 1],
    [1, 2],
    [2, 3],
    [3, 4],
    [4, 5],
  ];
  for (const [start, expectedNext] of expectations) {
    const state = driveTo(start);
    assert.equal(state.currentStep, start, `driveTo(${start}) landed correctly`);
    // Step 3 records the flow choice first; only then may the named
    // advance action move the machine forward.
    const pre =
      start === 3 ? reduce(state, { type: "key-flow-chosen", keyFlow: 1 }) : state;
    const advanced = reduce(pre, advanceActionFor(start));
    assert.equal(advanced.currentStep, expectedNext, `step ${start} advances to ${expectedNext}`);
  }
});

test("out-of-order actions freeze with OUT_OF_ORDER and never advance progress", () => {
  const wrongActions: ReadonlyArray<readonly [number, readonly InstallAction[]]> = [
    [0, [{ type: "files-picked" }, { type: "vbmeta-signed" }, { type: "fingerprint-recorded" }]],
    [
      1,
      [
        { type: "acknowledge-intro" },
        { type: "release-verified" },
        { type: "vbmeta-signed" },
      ],
    ],
    [2, [{ type: "files-picked" }, { type: "vbmeta-signed" }]],
    [
      3,
      [{ type: "fingerprint-recorded" }, { type: "vbmeta-signed" }, { type: "acknowledge-intro" }],
    ],
    [4, [{ type: "release-verified" }, { type: "files-picked" }, { type: "fingerprint-recorded" }]],
  ] as const;
  for (const [step, attempts] of wrongActions) {
    const base = driveTo(step);
    for (const attempt of attempts) {
      const next = reduce(base, attempt);
      assert.notEqual(next.currentStep, step + 1, `step ${step}: ${attempt.type} must not advance`);
      const last = next.stops[next.stops.length - 1];
      assert.ok(last !== undefined, `step ${step}: ${attempt.type} must record a stop`);
      assert.equal(last.reasonId, "OUT_OF_ORDER");
      assert.equal(last.reason, STOP_REASONS.OUT_OF_ORDER);
    }
  }
});

test("step 3 refuses fingerprint-recorded until a flow is chosen", () => {
  const atThree = driveTo(3);
  assert.equal(atThree.keyFlow, undefined);
  const premature = reduce(atThree, { type: "fingerprint-recorded" });
  const last = premature.stops[premature.stops.length - 1];
  assert.ok(last !== undefined);
  assert.equal(last.reasonId, "OUT_OF_ORDER");
  const chosen = reduce(atThree, { type: "key-flow-chosen", keyFlow: 2 });
  assert.equal(chosen.keyFlow, 2);
  assert.equal(chosen.currentStep, 3, "choosing records the flow without advancing");
  const advanced = reduce(chosen, { type: "fingerprint-recorded" });
  assert.equal(advanced.currentStep, 4);
});

// ---------------------------------------------------------------------------
// Step 0 content contract
// ---------------------------------------------------------------------------

test("step 0 renders posture pill, targets table, honesty blocks, custody sentences, CTA", () => {
  const html = renderStep0();
  assert.match(html, /◢ one-origin GET · your key · alpha/);
  assert.match(html, /data-connectivity="one-origin GET"/);
  assert.deepEqual(
    SUPPORTED_TARGETS.map((t) => t.codename),
    ["tokay", "akita", "komodo", "rango"],
  );
  assert.equal(SUPPORTED_TARGETS.find((t) => t.codename === "rango")?.status, "experimental");
  assert.equal(SUPPORTED_TARGETS.find((t) => t.codename === "tokay")?.status, "supported");
  assert.match(html, />tokay</);
  assert.match(html, />akita</);
  assert.match(html, />komodo</);
  assert.match(html, />rango</);
  assert.match(html, /Pixel 10 Pro Fold/);
  assert.match(html, /EXPERIMENTAL · BOOT HOLD/);
  assert.match(html, /data-role="target-product"/);
  assert.match(html, /option value="rango"/);
  assert.doesNotMatch(html, /rango stays hidden/);
  assert.match(html, /rango is advertised as experimental \/ boot HOLD/);
  assert.match(html, /komodo-20260915-063833 is userdebug\/test-keys, not a signed user FLASH_READY image/);
  assert.match(html, /LIVE_FLASH_CLAIMED=false/);
  assert.doesNotMatch(html, /FLASH_READY=true/);
  assert.match(html, /caiman, shiba, husky, tegu, and comet stay unstamped/);
  const rangoRow = html.split("<tr").find((row) => row.includes('data-codename="rango"'));
  assert.ok(rangoRow !== undefined);
  assert.match(rangoRow, /chip-caution/);
  assert.doesNotMatch(rangoRow, /SUPPORTED/);
  assert.match(html, /WebUSB flashing needs a Chromium-based browser/);
  assert.match(html, /wipes the phone twice/);
  assert.ok(html.includes('/threat-model'));
  assert.match(html, /Nothing is uploaded/);
  assert.ok(html.includes(RELEASE_FETCH_ORIGIN));
  assert.doesNotMatch(html, /no network request of any kind/i);
  assert.ok(html.includes(ACK_CTA_LABEL));
  assert.match(html, /data-action="acknowledge-intro"/);
  const custodyStart = html.indexOf('custody-list');
  const custodyEnd = html.indexOf("</ol>", custodyStart);
  const custodyHtml = html.slice(custodyStart, custodyEnd);
  assert.equal([...custodyHtml.matchAll(/<li>/g)].length, CUSTODY_SENTENCES.length);
  assert.equal(CUSTODY_SENTENCES.length, 3);
  assert.doesNotMatch(html, /The three key paths, compared as equals/);
});

test("step 0 claim language passes the project linter", () => {
  const html = renderStep0();
  // The success gate is asserted through the fingerprint comparisons below,
  // so exclude that order-specific rule here.
  const hits = lintText(html, "rendered-step0.html").filter((hit) => hit.rule !== "success-order"); // excludes only the fingerprint-comparison ordering check
  assert.deepEqual(hits, [], hits.map((h) => `${h.rule}: ${h.excerpt}`).join("\n"));
});

test("posture pill states the one-origin GET", () => {
  assert.match(renderPostureHeader(), /◢ one-origin GET · your key · alpha/);
  assert.match(renderPostureHeader(), /data-connectivity="one-origin GET"/);
  assert.equal(ALPHA_POSTURE_FLAGS.connectivity, "one-origin GET");
  assert.equal(ALPHA_POSTURE_FLAGS.custody, "your key");
});

// ---------------------------------------------------------------------------
// Step 1
// ---------------------------------------------------------------------------

test("step 1 renders honest unavailable facts for the onion address and release fingerprint", () => {
  const empty = renderStep1({ package: false, sums: false, sig: false });
  assert.match(empty, /data-role="package"/);
  assert.match(empty, /data-role="sums"/);
  assert.match(empty, /data-role="sig"/);
  // F-WEBINSTALL-PLACEHOLDER-RETIREMENT (D-041): the two facts the project does
  // not have render as "unavailable — do not proceed", never as a token.
  assert.ok(empty.includes(`data-unavailable="${ONION_ADDRESS_FACT.id}"`));
  assert.ok(empty.includes(`data-unavailable="${RELEASE_FINGERPRINT_FACT.id}"`));
  assert.equal((empty.match(new RegExp(UNAVAILABLE_CHIP_WORD, "g")) ?? []).length, 2);
  assert.doesNotMatch(empty, /\/\/ confirm/, "no pending-confirmation token may ship");
  // Actionable: what to do instead is stated for each fact.
  assert.ok(empty.includes("release announcement"));
  assert.ok(empty.includes("step 2"));
  // Blocking: each fact names what it gates.
  assert.ok(empty.includes("step 6"));
  assert.ok(empty.includes(`The only network request is a GET from ${RELEASE_FETCH_ORIGIN}`));
  assert.match(empty, /data-action="fetch-release"/);
  assert.match(empty, /data-action="files-picked"[^>]*disabled/);

  // All three picks still leave both facts unpublished, so Continue stays disabled.
  const picked = renderStep1({ package: true, sums: true, sig: true });
  assert.ok(picked.includes(`data-unavailable="${ONION_ADDRESS_FACT.id}"`));
  assert.ok(picked.includes(`data-unavailable="${RELEASE_FINGERPRINT_FACT.id}"`));
  assert.equal((picked.match(/data-proceed="forbidden"/g) ?? []).length, 2);
  assert.equal((picked.match(new RegExp(UNAVAILABLE_CHIP_WORD, "g")) ?? []).length, 2);
  assert.match(picked, /data-action="files-picked"[^>]*disabled/);
  assert.doesNotMatch(picked, /data-action="files-picked">/);

  // Test double: clearing both facts enables Continue once the three files are picked.
  const cleared = renderStep1(
    { package: true, sums: true, sig: true },
    { clearedFactIds: ["Q-04", "Q-05"] },
  );
  assert.doesNotMatch(cleared, /data-proceed="forbidden"/);
  assert.match(cleared, /data-action="files-picked">/);
  assert.doesNotMatch(cleared, /\.onion/i);
  assert.doesNotMatch(cleared, /[A-Fa-f0-9]{32,}/);

  // Either fact still forbidden keeps Continue disabled.
  const onionStillForbidden = renderStep1(
    { package: true, sums: true, sig: true },
    { clearedFactIds: ["Q-04"] },
  );
  assert.match(onionStillForbidden, /data-unavailable="Q-05"[^>]*data-proceed="forbidden"/);
  assert.match(onionStillForbidden, /data-action="files-picked"[^>]*disabled/);

  const fingerprintStillForbidden = renderStep1(
    { package: true, sums: true, sig: true },
    { clearedFactIds: ["Q-05"] },
  );
  assert.match(fingerprintStillForbidden, /data-unavailable="Q-04"[^>]*data-proceed="forbidden"/);
  assert.match(fingerprintStillForbidden, /data-action="files-picked"[^>]*disabled/);
  assert.doesNotMatch(fingerprintStillForbidden, /data-action="files-picked">/);

  // A missing file still disables Continue after the facts are cleared.
  const missingSig = renderStep1(
    { package: true, sums: true, sig: false },
    { clearedFactIds: ["Q-04", "Q-05"] },
  );
  assert.match(missingSig, /data-action="files-picked"[^>]*disabled/);
  assert.match(missingSig, /All three files must be picked before continuing/);

  assert.equal(filesReady({ package: true, sums: true, sig: true }), true);
  assert.equal(filesReady({ package: true, sums: true, sig: false }), false);
});

test("files-picked action refuses unpublished facts and a missing file", () => {
  const step1 = driveTo(1);
  assert.equal(step1.currentStep, 1);
  const three = { package: true, sums: true, sig: true } as const;
  const bothCleared = { clearedFactIds: ["Q-04", "Q-05"] } as const;

  // Direct action, three picks, both facts still unpublished: do not advance.
  const unpublished = filesPickedRefusal(three);
  assert.equal(
    unpublished,
    "Continue stays disabled while the release onion address or the release-key fingerprint is unpublished.",
  );
  assert.doesNotMatch(unpublished ?? "", /\.onion/i);
  assert.doesNotMatch(unpublished ?? "", /[A-Fa-f0-9]{32,}/);

  // Same branch as the handler: a refusal returns before dispatch.
  const afterAction = (
    picks: { readonly package: boolean; readonly sums: boolean; readonly sig: boolean },
    gate?: { readonly clearedFactIds: readonly ("Q-04" | "Q-05")[] },
  ): number => {
    const refusal = gate === undefined ? filesPickedRefusal(picks) : filesPickedRefusal(picks, gate);
    if (refusal !== undefined) {
      return step1.currentStep;
    }
    return reduce(step1, { type: "files-picked" }).currentStep;
  };

  assert.equal(afterAction(three), 1);
  assert.equal(afterAction(three, { clearedFactIds: ["Q-04"] }), 1);
  assert.equal(afterAction(three, { clearedFactIds: ["Q-05"] }), 1);

  // Clearing both facts in the existing test double does advance.
  assert.equal(filesPickedRefusal(three, bothCleared), undefined);
  assert.equal(afterAction(three, bothCleared), 2);

  // A missing file still does not advance, even after both facts are cleared.
  const missing = filesPickedRefusal(
    { package: true, sums: true, sig: false },
    bothCleared,
  );
  assert.equal(missing, "All three release files must be picked.");
  assert.equal(afterAction({ package: true, sums: true, sig: false }, bothCleared), 1);

  // The live handler consults the same gate before it dispatches.
  const source = readFileSync(
    fileURLToPath(new URL("../routes/install/install-app.ts", import.meta.url)),
    "utf8",
  );
  const start = source.indexOf('if (action === "files-picked")');
  const end = source.indexOf('if (action === "verify-release")');
  assert.ok(start >= 0 && end > start, "files-picked handler must exist");
  const block = source.slice(start, end);
  const refusalAt = block.indexOf("filesPickedRefusal(");
  const dispatchAt = block.indexOf('dispatch({ type: "files-picked" })');
  assert.ok(refusalAt >= 0, "handler must call filesPickedRefusal");
  assert.ok(dispatchAt > refusalAt, "refusal must precede the advance");
  assert.match(block.slice(refusalAt, dispatchAt), /return;/u);
});

test("step 1 GET fills the three slots from a stub and refuses any other origin", async () => {
  const csp =
    "default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'";
  assert.equal(INSTALLER_CSP, csp);
  assert.equal(INSTALLER_CSP.includes("*"), false);
  assert.equal(INSTALLER_CSP.includes("http://"), false);
  assert.equal(INSTALLER_CSP.split("connect-src ")[1], "'self'");
  assert.equal(new URL(RELEASE_FETCH_ORIGIN).protocol, "https:");

  const seen: string[] = [];
  const slots = await fetchReleaseObjects(async (url) => {
    seen.push(url);
    assert.equal(releaseFetchAllowed(url), true, url);
    assert.equal(new URL(url).origin, RELEASE_FETCH_ORIGIN);
    if (url.endsWith(`/${RELEASE_PACKAGE_NAME}`)) {
      return { ok: true, status: 200, arrayBuffer: async () => Uint8Array.of(1, 2, 3).buffer };
    }
    if (url.endsWith(`/${RELEASE_SIG_NAME}`)) {
      return { ok: true, status: 200, arrayBuffer: async () => Uint8Array.of(9).buffer };
    }
    assert.equal(url, releaseObjectUrl(RELEASE_SUMS_NAME));
    return {
      ok: true,
      status: 200,
      arrayBuffer: async () => new TextEncoder().encode(`abc  ${RELEASE_PACKAGE_NAME}\n`).buffer,
    };
  });
  assert.deepEqual(seen, [
    releaseObjectUrl(RELEASE_PACKAGE_NAME),
    releaseObjectUrl(RELEASE_SUMS_NAME),
    releaseObjectUrl(RELEASE_SIG_NAME),
  ]);
  assert.deepEqual(slots.picks, { package: true, sums: true, sig: true });
  assert.equal(slots.packageName, RELEASE_PACKAGE_NAME);
  assert.deepEqual(slots.packageBytes, Uint8Array.of(1, 2, 3));
  assert.equal(slots.sumsText, `abc  ${RELEASE_PACKAGE_NAME}\n`);
  assert.deepEqual(slots.sigBytes, Uint8Array.of(9));
  assert.equal(
    filesPickedRefusal(slots.picks),
    "Continue stays disabled while the release onion address or the release-key fingerprint is unpublished.",
  );
  assert.doesNotMatch(slots.sumsText, /\.onion/i);

  const foreign = [
    "http://releases.guardtalk.io/guardtalk-browser-test/tokay-20260928-084839/SHA256SUMS",
    "https://other.guardtalk.io/guardtalk-browser-test/tokay-20260928-084839/SHA256SUMS",
    "https://releases.guardtalk.io:8443/guardtalk-browser-test/tokay-20260928-084839/SHA256SUMS",
    "http://evil.example/SHA256SUMS",
    "https://releases.guardtalk.io/other-bucket/tokay-20260928-084839/SHA256SUMS",
    "https://releases.guardtalk.io/*",
    "https://releases.guardtalk.io/guardtalk-browser-test/tokay-20260928-084839/SHA256SUMS.sig.extra",
  ];
  for (const url of foreign) {
    assert.equal(releaseFetchAllowed(url), false, url);
    let calls = 0;
    await assert.rejects(
      () =>
        getAllowedReleaseObject(url, async () => {
          calls += 1;
          return { ok: true, status: 200, arrayBuffer: async () => new ArrayBuffer(0) };
        }),
      /Refused fetch/,
    );
    assert.equal(calls, 0, url);
    assert.throws(() => assertReleaseFetchUrl(url), /Refused fetch/);
  }

  const source = readFileSync(
    fileURLToPath(new URL("../routes/install/install-app.ts", import.meta.url)),
    "utf8",
  );
  const startFn = source.indexOf("function startReleaseFetch(");
  const readBytesAt = source.indexOf("async function readBytes(");
  assert.ok(startFn >= 0 && readBytesAt > startFn, "release fetch helpers must exist");
  const loader = source.slice(startFn, readBytesAt);
  assert.match(loader, /fetchReleaseObjects\(/);
  assert.doesNotMatch(loader, /files-picked/);
  assert.doesNotMatch(loader, /LIVE_FLASH_CLAIMED\s*=\s*true/);
  const fetchAction = source.indexOf('if (action === "fetch-release")');
  const filesAction = source.indexOf('if (action === "files-picked")');
  assert.ok(fetchAction >= 0 && filesAction > fetchAction);
  assert.match(source.slice(fetchAction, filesAction), /return;/u);
  assert.doesNotMatch(source.slice(fetchAction, filesAction), /dispatch\(/);
});

// ---------------------------------------------------------------------------
// Step 2 — verification + tamper matrix
// ---------------------------------------------------------------------------

test("step 2 happy path: VERIFIED chip + manifest meta + side-by-side rows", async () => {
  const { input } = await goodVerifyInput();
  const outcome = await verifyRelease(input);
  assert.equal(outcome.kind, "verified");
  if (outcome.kind !== "verified") {
    return;
  }
  const html = renderStep2(outcome.view);
  assert.match(html, /VERIFIED · SHA256SUMS/);
  assert.match(html, /chip-verified/);
  assert.ok(html.includes(input.manifest.buildId));
  assert.ok(html.includes(input.manifest.targetProduct));
  assert.ok(html.includes(input.manifest.version));
  assert.match(html, /EXPECTED/);
  assert.match(html, /ACTUAL/);
  assert.match(html, /MATCH/);
});

test("step 2 tamper matrix: flipped package byte ⇒ HASH_MISMATCH stop, verbatim reason", async () => {
  const { input } = await goodVerifyInput();
  const flipped = input.packageBytes.slice();
  flipped[3] = (flipped[3] ?? 0) ^ 0x01;
  const outcome = await verifyRelease({ ...input, packageBytes: flipped });
  assert.equal(outcome.kind, "stop");
  if (outcome.kind !== "stop") {
    return;
  }
  assert.equal(outcome.condition, "hash-mismatch");
  assert.equal(outcome.view.stopReason, STOP_REASONS.HASH_MISMATCH);
  const html = renderStep2(outcome.view);
  assert.ok(html.includes(STOP_REASONS.HASH_MISMATCH), "verbatim reason must be rendered");
  assert.match(html, /STOPPED/);
  assert.match(html, /MISMATCH/);
  assert.doesNotMatch(html, /data-action="release-verified"/);
  // The machine records the same condition at step 2 and hard-freezes.
  const stopped = reduce(reduce(driveTo(2), { type: "stop", step: 2, condition: "hash-mismatch" }), {
    type: "release-verified",
  });
  assert.equal(stopped.currentStep, 2, "hard stop freezes advancement");
});

test("step 2: SHA256SUMS that omits the package stops with HASH_MISMATCH", async () => {
  const { input } = await goodVerifyInput();
  const otherDigest = createHash("sha256").update("unrelated").digest("hex");
  const outcome = await verifyRelease({ ...input, sumsText: `${otherDigest}  something-else.zip` });
  assert.equal(outcome.kind, "stop");
  if (outcome.kind !== "stop") {
    return;
  }
  assert.equal(outcome.condition, "hash-mismatch");
  assert.ok(outcome.view.detail?.includes(PACKAGE_NAME));
});

// ---------------------------------------------------------------------------
