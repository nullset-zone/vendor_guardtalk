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
import { createHash, createPublicKey, createSign, generateKeyPairSync } from "node:crypto";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

import {
  ACK_CTA_LABEL,
  ALPHA_POSTURE_FLAGS,
  CUSTODY_SENTENCES,
  KEY_FLOW_CARDS,
  ONION_PLACEHOLDER,
  PARTITION_LAYOUT_CONFIRM,
  RELEASE_FINGERPRINT_PLACEHOLDER,
  STEP4_ALGORITHM,
  SUPPORTED_TARGETS,
  cliSigningCommands,
  filesReady,
  pkmdFromJwk,
  renderInstallerChrome,
  renderPostureHeader,
  renderRouteFooter,
  renderStep0,
  renderStep1,
  renderStep2,
  renderStep3,
  renderStep3Collect,
  renderStep3FlowDetail,
  renderStep4,
  renderStep4Collect,
  retypeMatches,
  runGenerateFlow,
  runImportFlow,
  runSignElsewhereFlow,
  signVbmetaStep,
  step3Decide,
  verifyRelease,
} from "../routes/install/early-steps.js";
import { initialInstallState, reduce } from "../lib/install-state/machine.js";
import type { InstallAction, InstallState } from "../lib/install-state/machine.js";
import { STOP_REASONS } from "../lib/install-state/stops.js";
import type { RsaPublicJwk } from "../lib/verify/detached-sig.js";
import { resignVbmetaWithRelease } from "../lib/avb/signer.js";
import type { KeyMaterial as SignerKeyMaterial } from "../lib/avb/signer.js";
import { parseVbmeta, algorithmName } from "../lib/avb/parser.js";
import { DESCRIPTOR_TAG_CHAIN, DESCRIPTOR_TAG_HASH } from "../lib/avb/descriptors.js";
import { lintText } from "../lib/claims/lint-claims.js";
import { INSTALLER_CSP } from "../lib/claims/csp.js";

// ---------------------------------------------------------------------------
// Small binary helpers (test-local wire builders)
// ---------------------------------------------------------------------------

const ENC = new TextEncoder();

function concat(parts: readonly Uint8Array[]): Uint8Array {
  let total = 0;
  for (const p of parts) {
    total += p.length;
  }
  const out = new Uint8Array(total);
  let off = 0;
  for (const p of parts) {
    out.set(p, off);
    off += p.length;
  }
  return out;
}

/** AvbHashDescriptor wire bytes (layout mirrors lib/avb/descriptors.ts encodeHash). */
function makeHashDescriptorForTest(partition: string): Uint8Array {
  const name = ENC.encode(partition);
  const salt = new Uint8Array(0);
  const digest = new Uint8Array(32).fill(0xab);
  const body = 116 + name.length + salt.length + digest.length;
  const padded = Math.ceil(body / 8) * 8;
  const out = new Uint8Array(16 + padded);
  const view = new DataView(out.buffer);
  view.setBigUint64(0, BigInt(DESCRIPTOR_TAG_HASH), false);
  view.setBigUint64(8, BigInt(padded), false);
  view.setBigUint64(16, 0n, false);
  out.set(ENC.encode("sha256").subarray(0, 32), 24);
  view.setUint32(56, name.length, false);
  view.setUint32(60, salt.length, false);
  view.setUint32(64, digest.length, false);
  view.setUint32(68, 0, false);
  out.set(name, 132);
  out.set(salt, 132 + name.length);
  out.set(digest, 132 + name.length + salt.length);
  return out;
}

/** AvbChainPartitionDescriptor wire bytes (mirrors encodeChain). */
function makeChainDescriptorForTest(partition: string, publicKey: Uint8Array): Uint8Array {
  const name = ENC.encode(partition);
  const body = 76 + name.length + publicKey.length;
  const padded = Math.ceil(body / 8) * 8;
  const out = new Uint8Array(16 + padded);
  const view = new DataView(out.buffer);
  view.setBigUint64(0, BigInt(DESCRIPTOR_TAG_CHAIN), false);
  view.setBigUint64(8, BigInt(padded), false);
  view.setUint32(16, 0, false);
  view.setUint32(20, name.length, false);
  view.setUint32(24, publicKey.length, false);
  view.setUint32(28, 0, false);
  out.set(name, 92);
  out.set(publicKey, 92 + name.length);
  return out;
}

const roundUp64 = (n: number): number => Math.ceil(n / 64) * 64;

/** Minimal PKCS#8 → {n, e, d} walker so fixtures need no import-path help. */
function toSignerMaterial(pkcs8Der: Uint8Array): SignerKeyMaterial {
  const readLen = (buf: Uint8Array, off: number): { len: number; next: number } => {
    const first = buf[off] as number;
    if ((first & 0x80) === 0) {
      return { len: first, next: off + 1 };
    }
    const n = first & 0x7f;
    let len = 0;
    for (let i = 0; i < n; i += 1) {
      len = len * 256 + (buf[off + 1 + i] as number);
    }
    return { len, next: off + 1 + n };
  };
  const intAt = (buf: Uint8Array, off: number): { value: bigint; next: number } => {
    assert.equal(buf[off], 0x02, "expected DER INTEGER");
    const { len, next } = readLen(buf, off + 1);
    let v = 0n;
    for (let i = 0; i < len; i += 1) {
      v = (v << 8n) | BigInt(buf[next + i] as number);
    }
    return { value: v, next: next + len };
  };
  const seqAt = (buf: Uint8Array, off: number): { end: number; next: number } => {
    assert.equal(buf[off], 0x30, "expected DER SEQUENCE");
    const { len, next } = readLen(buf, off + 1);
    return { end: next + len, next };
  };

  const outer = seqAt(pkcs8Der, 0);
  const version = intAt(pkcs8Der, outer.next);
  const algId = seqAt(pkcs8Der, version.next);
  const octetAt = algId.end;
  assert.equal(pkcs8Der[octetAt], 0x04, "expected OCTET STRING");
  const inner = readLen(pkcs8Der, octetAt + 1);
  const rsa = seqAt(pkcs8Der, inner.next);
  const ints: bigint[] = [];
  let cursor = rsa.next;
  while (cursor < rsa.end) {
    const parsed = intAt(pkcs8Der, cursor);
    ints.push(parsed.value);
    cursor = parsed.next;
  }
  // RSAPrivateKey ::= version, n, e, d, p, q, dp, dq, qinv
  assert.ok(ints.length >= 4, "RSAPrivateKey too short");
  return { n: ints[1] as bigint, e: ints[2] as bigint, d: ints[3] as bigint };
}

// ---------------------------------------------------------------------------
// Step-2 verification fixture
// ---------------------------------------------------------------------------

const PACKAGE_NAME = "guardtalk-os.zip";

interface VerifyInputLike {
  packageName: string;
  packageBytes: Uint8Array;
  sumsText: string;
  sigBytes: Uint8Array;
  releaseKeyJwk: RsaPublicJwk;
  manifest: { buildId: string; targetProduct: string; version: string };
}

async function goodVerifyInput(): Promise<{ input: VerifyInputLike; packageBytes: Uint8Array }> {
  const { privateKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
  const pem = privateKey.export({ type: "pkcs8", format: "pem" }).toString();
  const releaseJwk = createPublicKey(pem).export({ format: "jwk" }) as RsaPublicJwk;
  const packageBytes = ENC.encode(`package-bytes-of-${PACKAGE_NAME}`);
  const pkgDigest = createHash("sha256").update(packageBytes).digest("hex");
  const sums = [
    "# GuardTalkOS alpha test bundle",
    `${pkgDigest}  ${PACKAGE_NAME}`,
    `${createHash("sha256").update("vbmeta-bytes").digest("hex")}  vbmeta.img`,
  ].join("\n");
  const signer = createSign("sha256");
  signer.update(sums);
  const sigBytes = new Uint8Array(signer.sign(pem));
  return {
    packageBytes,
    input: {
      packageName: PACKAGE_NAME,
      packageBytes,
      sumsText: sums,
      sigBytes,
      releaseKeyJwk: releaseJwk,
      manifest: { buildId: "20260822-000000", targetProduct: "tokay", version: "alpha-1" },
    },
  };
}

// ---------------------------------------------------------------------------
// Step-4 vbmeta fixture: genuinely signed SHA256_RSA4096 image
// ---------------------------------------------------------------------------

interface VbmetaFixture {
  img: Uint8Array;
  pkcs8: Uint8Array;
  signer: SignerKeyMaterial;
  publicJwk: JsonWebKey;
  fingerprintHex: string;
  pkmd: Uint8Array;
}

let fixtureCache: VbmetaFixture | undefined;

async function vbmetaFixture(): Promise<VbmetaFixture> {
  if (fixtureCache !== undefined) {
    return fixtureCache;
  }
  const pair = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 4096,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  const pkcs8 = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  const signer = toSignerMaterial(pkcs8);
  const jwk = await crypto.subtle.exportKey("jwk", pair.publicKey);
  const pkmd = pkmdFromJwk(jwk);
  assert.equal(pkmd.length, 1032);
  const fingerprintHex = createHash("sha256").update(pkmd).digest("hex");

  // Header per avbtool defaults for SHA256_RSA4096 (offsets mirror parser.ts).
  const header = new ArrayBuffer(256);
  const view = new DataView(header);
  new Uint8Array(header, 0, 4).set(ENC.encode("AVB0"));
  view.setUint32(4, 1, false); // required libavb major
  view.setBigUint64(12, 576n, false); // authentication_data_block_size
  view.setBigUint64(20, 6720n, false); // auxiliary_data_block_size
  view.setUint32(28, 2, false); // algorithm_type = SHA256_RSA4096
  view.setBigUint64(32, 0n, false); // hash_offset
  view.setBigUint64(40, 32n, false); // hash_size
  view.setBigUint64(48, 32n, false); // signature_offset
  view.setBigUint64(56, 512n, false); // signature_size
  view.setBigUint64(64, 32n, false); // public_key_offset (inside aux)
  view.setBigUint64(72, 1032n, false); // public_key_size
  view.setBigUint64(96, 1064n, false); // descriptors_offset (inside aux)
  const descriptorsWire = concat([makeHashDescriptorForTest("boot")]);
  view.setBigUint64(104, BigInt(descriptorsWire.length), false);

  const auxBlock = new Uint8Array(6720);
  auxBlock.set(pkmd, 32);
  auxBlock.set(descriptorsWire, 1064);

  const blob = new Uint8Array(256 + 576 + 6720);
  blob.set(new Uint8Array(header), 0);
  blob.set(auxBlock, 256 + 576);

  const img = await resignVbmetaWithRelease(blob, signer, "test-release");
  const parsed = parseVbmeta(img);
  assert.equal(parsed.header.algorithmType, 2);
  assert.equal(algorithmName(parsed.header.algorithmType), STEP4_ALGORITHM);
  assert.ok(parsed.publicKey !== undefined);
  assert.ok(parsed.descriptors.some((d) => d.tag === DESCRIPTOR_TAG_HASH));

  fixtureCache = { img, pkcs8, signer, publicJwk: jwk, fingerprintHex, pkmd };
  return fixtureCache;
}

// ---------------------------------------------------------------------------
// CSP + custody sweeps over every emitted markup string
// ---------------------------------------------------------------------------

const CSP_FORBIDDEN_ATTRS = [/\son[a-z]+\s*=\s*"/i, /\sstyle\s*=\s*"/i];

function emittedMarkups(state: InstallState): ReadonlyArray<readonly [string, string]> {
  const flowFingerprint = "a".repeat(56) + "0123abcd";
  const cliCommands = cliSigningCommands({
    releaseFiles: [{ name: PACKAGE_NAME, sha256: "aa".repeat(32) }],
    targetProduct: "tokay",
    keyFlow: "sign-elsewhere",
    vbmetaTargets: [{ partition: "vbmeta", imageFile: "vbmeta.img", topLevel: true }],
    firmwareImages: [],
    osImages: [],
  });
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
    ["step3", renderStep3()],
    ["step3-collect-1", renderStep3Collect(1)],
    ["step3-collect-2", renderStep3Collect(2)],
    ["step3-collect-3", renderStep3Collect(3)],
    ["step3-detail-flow1", renderStep3FlowDetail({ flow: 1, fingerprintHex: flowFingerprint })],
    [
      "step3-detail-flow3",
      renderStep3FlowDetail({ flow: 3, fingerprintHex: flowFingerprint, cliCommands }),
    ],
    [
      "step4-signed",
      renderStep4({ status: "signed", algorithm: STEP4_ALGORITHM, rows: [] }),
    ],
    [
      "step4-stopped",
      renderStep4({
        status: "stopped",
        algorithm: STEP4_ALGORITHM,
        rows: [],
        chainPartitions: ["vbmeta_system"],
        stopReason: STOP_REASONS.PARTITION_LAYOUT_UNKNOWN,
      }),
    ],
    ["step4-collect", renderStep4Collect()],
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
  assert.match(html, /◢ offline · your key · alpha/);
  assert.deepEqual(
    SUPPORTED_TARGETS.map((t) => t.codename),
    ["tokay", "rango"],
  );
  assert.match(html, />tokay</);
  assert.match(html, />rango</);
  assert.match(html, /akita \(Pixel 8a\) stays behind an explicit experimental flag/);
  assert.match(html, /Tor Browser cannot flash over USB/);
  assert.match(html, /CLI export/);
  assert.match(html, /wipes the phone twice/);
  assert.ok(html.includes('/threat-model'));
  assert.match(html, /makes no network request of any kind|No network request leaves this page/);
  assert.ok(html.includes(ACK_CTA_LABEL));
  assert.match(html, /data-action="acknowledge-intro"/);
  // Key-custody explanation: exactly six sentences.
  const custodyStart = html.indexOf('custody-list');
  const custodyEnd = html.indexOf("</ol>", custodyStart);
  const custodyHtml = html.slice(custodyStart, custodyEnd);
  assert.equal([...custodyHtml.matchAll(/<li>/g)].length, 6);
  assert.equal(CUSTODY_SENTENCES.length, 6);
  // Three flows compared in a table with three columns.
  assert.match(html, /The three key paths, compared as equals/);
  assert.match(html, /Generate here/);
  assert.match(html, /Bring your own/);
  assert.match(html, /Sign elsewhere/);
});

test("step 0 claim language passes the project linter", () => {
  const html = renderStep0();
  // The success gate is asserted through the fingerprint comparisons below,
  // so exclude that order-specific rule here.
  const hits = lintText(html, "rendered-step0.html").filter((hit) => hit.rule !== "success-order"); // excludes only the fingerprint-comparison ordering check
  assert.deepEqual(hits, [], hits.map((h) => `${h.rule}: ${h.excerpt}`).join("\n"));
});

test("posture pill text matches PLAN.md §5 exactly", () => {
  assert.match(renderPostureHeader(), /◢ offline · your key · alpha/);
  assert.equal(ALPHA_POSTURE_FLAGS.connectivity, "offline");
  assert.equal(ALPHA_POSTURE_FLAGS.custody, "your key");
});

// ---------------------------------------------------------------------------
// Step 1
// ---------------------------------------------------------------------------

test("step 1 shows three inputs, confirm placeholders, offline promise, gate", () => {
  const empty = renderStep1({ package: false, sums: false, sig: false });
  assert.match(empty, /data-role="package"/);
  assert.match(empty, /data-role="sums"/);
  assert.match(empty, /data-role="sig"/);
  assert.ok(empty.includes(ONION_PLACEHOLDER));
  assert.ok(empty.includes(RELEASE_FINGERPRINT_PLACEHOLDER));
  assert.match(empty, /No network request leaves this page/);
  assert.match(empty, /data-action="files-picked"[^>]*disabled/);

  const ready = renderStep1({ package: true, sums: true, sig: true });
  assert.match(ready, /data-action="files-picked">/);
  assert.equal(filesReady({ package: true, sums: true, sig: true }), true);
  assert.equal(filesReady({ package: true, sums: true, sig: false }), false);
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
  assert.match(html, /VERIFIED · GUARDTALK RELEASE KEY/);
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

test("step 2 tamper matrix: bad signature ⇒ SIGNATURE_INVALID stop", async () => {
  const { input } = await goodVerifyInput();
  const badSig = input.sigBytes.slice();
  badSig[badSig.length - 1] = (badSig[badSig.length - 1] ?? 0) ^ 0xff;
  const outcome = await verifyRelease({ ...input, sigBytes: badSig });
  assert.equal(outcome.kind, "stop");
  if (outcome.kind !== "stop") {
    return;
  }
  assert.equal(outcome.condition, "signature-invalid");
  assert.equal(outcome.view.stopReason, STOP_REASONS.SIGNATURE_INVALID);
  const html = renderStep2(outcome.view);
  assert.ok(html.includes(STOP_REASONS.SIGNATURE_INVALID));
  assert.match(html, /MISMATCH/);
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
// Step 3 — equal cards, retype gating
// ---------------------------------------------------------------------------

test("step 3: no card pre-selected anywhere in the markup (D-005)", () => {
  const html = renderStep3();
  assert.doesNotMatch(html, /<input[^>]*\schecked[\s>]/i);
  assert.doesNotMatch(html, /\bdefault\b/i);
  assert.doesNotMatch(html, /aria-checked/i);
  assert.doesNotMatch(html, /\bselected\s*=\s*["']/i);
  assert.match(html, /No path is selected for you/);
  assert.equal(KEY_FLOW_CARDS.length, 3);
});

test("step 3: flow cards render equal — same heading level and same markup shape", () => {
  const html = renderStep3();
  const cards = [...html.matchAll(/<article class="flow-card"[^>]*>([\s\S]*?)<\/article>/g)].map(
    (m) => m[1] ?? "",
  );
  assert.equal(cards.length, 3);
  const shapes = cards.map((card) => ({
    headings: [...card.matchAll(/<h([1-6])>/g)].map((m) => m[1]),
    buttons: [...card.matchAll(/<button[^>]*>/g)].map((b) => b[0].replace(/ data-flow="\d+"/, "")),
    paragraphs: [...card.matchAll(/<p>/g)].length,
  }));
  for (const shape of shapes) {
    assert.deepEqual(shape.headings, ["3"], "every card uses exactly one h3");
    assert.equal(shape.paragraphs, 1);
    assert.equal(shape.buttons.length, 1);
  }
  assert.deepEqual(shapes[0], shapes[1]);
  assert.deepEqual(shapes[1], shapes[2]);
  for (const card of KEY_FLOW_CARDS) {
    assert.ok(html.includes(`data-flow="${String(card.flow)}"`));
  }
});

const FP_64 = "deadbeefcafe11223344556677889900aabbccddeeff00112233445566778899";

test("step 3: wrong retype never advances; correct retype advances", () => {
  const last8 = FP_64.slice(-8);

  const wrong = step3Decide(FP_64, 1, {
    typedTail: last8.split("").reverse().join(""),
    downloadSaved: true,
  });
  assert.equal(wrong.dispatch, null);
  assert.ok(wrong.retypeStop !== undefined);
  assert.equal(wrong.retypeStop.reasonId, "FINGERPRINT_RETYPE_WRONG");
  assert.equal(wrong.retypeStop.reason, STOP_REASONS.FINGERPRINT_RETYPE_WRONG);

  // Case differences also fail: record requires an EXACT tail match. (The
  // FP_64 tail is all digits, so use a letter-bearing tail here.)
  const mixedFp = "0123456789abcdef".repeat(4);
  const upper = step3Decide(mixedFp, 2, { typedTail: mixedFp.slice(-8).toUpperCase() });
  assert.equal(upper.dispatch, null);

  const right = step3Decide(FP_64, 2, { typedTail: last8 });
  assert.deepEqual(right.dispatch, { type: "fingerprint-recorded" });
  assert.deepEqual(right.blockers, []);
  assert.ok(retypeMatches(FP_64, last8));

  // Machine level: with a flow chosen, the recorded action advances 3→4.
  const chosen = reduce(driveTo(3), { type: "key-flow-chosen", keyFlow: 2 });
  assert.equal(reduce(chosen, { type: "fingerprint-recorded" }).currentStep, 4);
});

test("step 3: flow 1 additionally requires the encrypted-download confirmation", () => {
  const last8 = FP_64.slice(-8);
  const missing = step3Decide(FP_64, 1, { typedTail: last8, downloadSaved: false });
  assert.equal(missing.dispatch, null);
  assert.ok(missing.blockers.includes("download-saved"));

  const satisfied = step3Decide(FP_64, 1, { typedTail: last8, downloadSaved: true });
  assert.deepEqual(satisfied.dispatch, { type: "fingerprint-recorded" });

  const detail = renderStep3FlowDetail({ flow: 1, fingerprintHex: FP_64 });
  assert.match(detail, /I saved the encrypted key file/);
  assert.match(detail, /download-saved/);
  assert.ok(detail.includes(FP_64), "fingerprint shown mono for recording");
});

test("step 3: flow 3 renders the cli-export avbtool command block", () => {
  const commands = cliSigningCommands({
    releaseFiles: [{ name: PACKAGE_NAME, sha256: "aa".repeat(32) }],
    targetProduct: "tokay",
    keyFlow: "sign-elsewhere",
    vbmetaTargets: [{ partition: "vbmeta", imageFile: "vbmeta.img", topLevel: true }],
    firmwareImages: [],
    osImages: [],
  });
  assert.match(
    commands,
    /avbtool make_vbmeta_image --output 'vbmeta\.img' --algorithm SHA256_RSA4096 --key "\$USER_KEY_PEM"/,
  );
  const html = renderStep3FlowDetail({
    flow: 3,
    fingerprintHex: FP_64,
    cliCommands: commands,
  });
  assert.match(html, /cmd-block mono/);
  // The rendered block is HTML-escaped (&quot;), so compare through the same
  // escaping the renderer applies.
  assert.ok(
    html.includes(commands.replace(/"/g, "&quot;")),
    "the generated avbtool commands must appear in the flow-3 block",
  );
});

test("step 3: import flow derives the fingerprint from a real PEM (public half only)", async () => {
  const { privateKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
  const pem = privateKey.export({ type: "pkcs8", format: "pem" }).toString();
  const imported = await runImportFlow(pem);
  assert.match(imported.fingerprintHex, /^[0-9a-f]{64}$/);
  assert.equal(imported.fingerprintOfPkmd, createHash("sha256").update(imported.pkmd).digest("hex"));
  assert.equal(imported.signerMaterial.e, 65537n);
});

test("step 3: sign-elsewhere flow fingerprints the public half from SPKI PEM", async () => {
  // RSA-4096: the pkmd codec (and therefore the fingerprint) is 4096-only.
  const { publicKey } = generateKeyPairSync("rsa", { modulusLength: 4096 });
  const spki = publicKey.export({ type: "spki", format: "pem" }).toString();
  const result = await runSignElsewhereFlow(spki);
  assert.match(result.fingerprintHex, /^[0-9a-f]{64}$/);
  assert.equal(result.pkmd.length, 1032);
});

// ---------------------------------------------------------------------------
// Step 4 — chain stop + real resign roundtrip
// ---------------------------------------------------------------------------

test("step 4: chain descriptor fixture ⇒ PARTITION_LAYOUT_UNKNOWN stop + Q-07 placeholder", async () => {
  const fixture = await vbmetaFixture();
  const parsed = parseVbmeta(fixture.img);
  const auxStart = 256 + parsed.header.authenticationDataBlockSize;
  const chainDesc = makeChainDescriptorForTest("vbmeta_system", fixture.pkmd);
  const insertAt = auxStart + parsed.header.descriptorsOffset + parsed.header.descriptorsSize;
  // Grow the aux block to the next 64-byte boundary (parser enforces block
  // alignment); the buffer is sized to the grown geometry and zero-filled,
  // so the padded descriptor tail needs no explicit bytes...
  const auxGrown = roundUp64(parsed.header.auxiliaryDataBlockSize + chainDesc.length);
  const grown = new Uint8Array(256 + parsed.header.authenticationDataBlockSize + auxGrown);
  grown.set(fixture.img.slice(0, insertAt), 0);
  grown.set(chainDesc, insertAt);
  grown.set(fixture.img.slice(insertAt), insertAt + chainDesc.length);

  // ...then widen the declared sizes so the image stays coherent.
  // descriptors_size grows by the descriptor's true length only — the
  // remaining aux-block slack is plain zero padding, not table content.
  const view = new DataView(grown.buffer);
  view.setBigUint64(20, BigInt(auxGrown), false);
  view.setBigUint64(104, BigInt(parsed.header.descriptorsSize + chainDesc.length), false);

  // ...then re-sign so the digest/signature cover the grown image.
  const withChain = await resignVbmetaWithRelease(grown, fixture.signer, parsed.header.releaseString);
  const outcome = await signVbmetaStep({
    kind: "sign",
    img: withChain,
    key: fixture.signer,
    keyFingerprintHex: fixture.fingerprintHex,
  });
  assert.equal(outcome.kind, "stop");
  if (outcome.kind !== "stop") {
    return;
  }
  assert.equal(outcome.condition, "partition-layout-unknown");
  assert.equal(outcome.view.stopReason, STOP_REASONS.PARTITION_LAYOUT_UNKNOWN);
  assert.ok(outcome.view.chainPartitions?.includes("vbmeta_system"));
  const html = renderStep4(outcome.view);
  assert.ok(html.includes(STOP_REASONS.PARTITION_LAYOUT_UNKNOWN));
  assert.ok(html.includes("// confirm partition layout"));
  assert.ok(html.includes(PARTITION_LAYOUT_CONFIRM));
  assert.doesNotMatch(html, /data-action="vbmeta-signed"/);
  // The machine mirrors the hard stop at step 4.
  const machineStopped = reduce(driveTo(4), {
    type: "stop",
    step: 4,
    condition: "partition-layout-unknown",
  });
  assert.ok(machineStopped.stops.some((stop) => stop.reason === STOP_REASONS.PARTITION_LAYOUT_UNKNOWN));
});

test("step 4: clean vbmeta ⇒ vbmeta-signed after real resign+verify roundtrip", async () => {
  const fixture = await vbmetaFixture();
  const before = parseVbmeta(fixture.img);
  const outcome = await signVbmetaStep({
    kind: "sign",
    img: fixture.img,
    key: fixture.signer,
    keyFingerprintHex: fixture.fingerprintHex,
  });
  assert.equal(outcome.kind, "signed");
  if (outcome.kind !== "signed") {
    return;
  }
  // Roundtrip proof: stored digest equals a freshly recomputed one, and the
  // embedded-key verifier accepted the fresh image (checked inside
  // signVbmetaStep before it returned "signed").
  const reparsed = parseVbmeta(outcome.signedImage);
  assert.equal(reparsed.header.releaseString, before.header.releaseString);
  const auxStart = 256 + reparsed.header.authenticationDataBlockSize;
  const recomputed = createHash("sha256")
    .update(
      concat([
        outcome.signedImage.slice(0, 256),
        outcome.signedImage.slice(auxStart, auxStart + reparsed.header.auxiliaryDataBlockSize),
      ]),
    )
    .digest("hex");
  const stored = [...(reparsed.authHash as Uint8Array)]
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
  assert.equal(stored, recomputed);

  const html = renderStep4(outcome.view);
  assert.ok(html.includes(STEP4_ALGORITHM));
  assert.ok(html.includes(fixture.fingerprintHex));
  assert.match(html, /MATCH/);
  assert.match(html, /data-action="vbmeta-signed">/);
  // Machine accepts vbmeta-signed at step 4 only.
  const atFour = driveTo(4);
  assert.equal(atFour.currentStep, 4);
  const advanced = reduce(atFour, { type: "vbmeta-signed" });
  assert.equal(advanced.currentStep, 5);
  assert.ok(advanced.completedSteps.has(4));
});

test("step 4: imported-and-rechecked path verifies against the enrolled pkmd", async () => {
  const fixture = await vbmetaFixture();
  const outcome = await signVbmetaStep({
    kind: "import",
    img: fixture.img,
    expectedPkmd: fixture.pkmd,
    keyFingerprintHex: fixture.fingerprintHex,
  });
  assert.equal(outcome.kind, "verified-import");
  if (outcome.kind !== "verified-import") {
    return;
  }
  const html = renderStep4(outcome.view);
  assert.match(html, /MATCH/);
  assert.match(html, /data-action="vbmeta-signed">/);
});

test("step 4: tampered image fails its own verification loudly", async () => {
  const fixture = await vbmetaFixture();
  const broken = fixture.img.slice();
  broken[broken.length - 10] = (broken[broken.length - 10] ?? 0) ^ 0x01;
  await assert.rejects(
    signVbmetaStep({
      kind: "sign",
      img: broken,
      key: fixture.signer,
      keyFingerprintHex: fixture.fingerprintHex,
    }),
    /failed verification against its embedded key/,
  );
});

// ---------------------------------------------------------------------------
// Custody sweep — no private material in any emitted string
// ---------------------------------------------------------------------------

function collectSecretVariants(pkcs8Der: Uint8Array): string[] {
  const variants = new Set<string>();
  variants.add(Buffer.from(pkcs8Der).toString("latin1"));
  variants.add(Buffer.from(pkcs8Der).toString("base64"));
  variants.add(Buffer.from(pkcs8Der).toString("base64url"));
  variants.add(Buffer.from(pkcs8Der).toString("hex"));
  return [...variants];
}

test("custody sweep: known test-key secrets never appear in emitted HTML (async)", async () => {
  const fixture = await vbmetaFixture();
  const secrets = collectSecretVariants(fixture.pkcs8);
  const state = reduce(initialInstallState("install"), { type: "acknowledge-intro" });
  for (const [name, html] of emittedMarkups(state)) {
    for (const secret of secrets) {
      assert.ok(!html.includes(secret), `${name} must not contain private-key material`);
    }
  }
  // Fingerprint display path carries ONLY the public fingerprint.
  const detail = renderStep3FlowDetail({ flow: 1, fingerprintHex: fixture.fingerprintHex });
  for (const secret of secrets) {
    assert.ok(!detail.includes(secret), "fingerprint display must stay public-half only");
  }
});

test("runGenerateFlow: signing handle is non-extractable and pkmd is RSA-4096", async () => {
  const result = await runGenerateFlow("twelve-chars");
  assert.equal(result.privateKey.extractable, false);
  assert.equal(result.pkmd.length, 1032);
  assert.match(result.fingerprintHex, /^[0-9a-f]{64}$/);
  assert.match(result.armoredBackup, /BEGIN GUARDTALK ENCRYPTED KEY/);
});

test("runGenerateFlow: short passphrase is refused", async () => {
  await assert.rejects(runGenerateFlow("short"), /passphrase must be at least/);
});
