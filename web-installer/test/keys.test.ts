/**
 * keys foundation tests: generate → fingerprint determinism (fixed vector),
 * PEM import paths built from a real constructed RSA key, export-enc
 * roundtrips, clean failure on wrong passphrase, zeroise behaviour, and the
 * D-007 key-leak source scan over lib/keys/*.ts.
 *
 * Fixture strategy: one WebCrypto RSA-2048 key pair (extractable twin of the
 * production non-extractable handle) is generated per run and serialized to
 * PKCS#8 / SPKI / JWK. PKCS#1 is produced by stripping the PKCS#8 wrapper
 * with the same DER walker the importer uses, so all three PEM labels are
 * exercised by a genuine key without any third-party dependency.
 */
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { test } from "node:test";
import { exportPublicJwk, generateKey } from "../lib/keys/generate.js";
import { fingerprintFromJwk } from "../lib/keys/fingerprint.js";
import { importPem } from "../lib/keys/import.js";
import {
  decryptEncryptedPem,
  exportEncryptedPem,
  KeyExportError,
  PASSPHRASE_MIN_LENGTH,
} from "../lib/keys/export-enc.js";
import { onPageHide, scrub, zeroise } from "../lib/keys/zeroise.js";
import { encodePkmd, pkmdFingerprint } from "../lib/avb/pkmd.js";

// --- generate + fingerprint ---------------------------------------------------

test("generate: RSA-4096 pair with non-extractable private handle", async () => {
  const { privateKey, publicKey } = await generateKey();
  assert.equal(privateKey.extractable, false);
  assert.equal(publicKey.extractable, true);
  const algorithm = privateKey.algorithm as RsaAlgorithm;
  assert.equal(algorithm.modulusLength, 4096);
  assert.equal(algorithm.name, "RSASSA-PKCS1-v1_5");
  const jwk = await exportPublicJwk(publicKey);
  assert.equal(jwk.kty, "RSA");
  assert.equal(jwk.d, undefined);
  assert.equal(jwk.p, undefined);
});

test("fingerprint: deterministic for a fixed JWK vector", async () => {
  // Fixed RFC-aligned RSA test vector (n, e only) — generation-independent.
  const jwk = fixedJwk();
  const fp1 = await fingerprintFromJwk(jwk);
  const fp2 = await fingerprintFromJwk({ ...jwk });
  assert.equal(fp1, fp2);
  assert.match(fp1, /^[0-9a-f]{64}$/);

  // Cross-check against the pkmd module directly (single encoding source).
  const n = b64uToBigint(jwk.n);
  const pkmd = encodePkmd({ n, e: 65537n });
  assert.equal(pkmd.length, 1032);
  const expected = await sha256HexOf(pkmd);
  assert.equal(fp1, expected);
});

test("fingerprint: rejects non-65537 exponents", async () => {
  await assert.rejects(fingerprintFromJwk(fixedJwk(3)), /exponent/);
});

// --- import: unencrypted PEM labels ---------------------------------------------

test("import: PKCS#8 PEM parses to material + JWK", async () => {
  const fixture = await pemFixtures();
  const imported = await importPem(fixture.pkcs8Pem);
  assert.equal(imported.publicJwk.kty, "RSA");
  assert.equal(imported.material.n.length, 256); // 2048-bit modulus
  assert.ok(imported.material.e.length <= 3);
  assert.equal(bytesToBigint(imported.material.e), 65537n);
  // Public half matches what WebCrypto exports for the same key.
  assert.equal(
    normalizeJwk(imported.publicJwk),
    normalizeJwk(await exportPublicJwk(fixture.publicKey)),
  );
});

test("import: PKCS#8 PEM round-trips through fingerprint", async () => {
  const fixture = await pemFixtures();
  const viaImport = await fingerprintFromJwk((await importPem(fixture.pkcs8Pem)).publicJwk);
  const viaHandle = await fingerprintFromJwk(await exportPublicJwk(fixture.publicKey));
  assert.equal(viaImport, viaHandle);
});

test("import: PKCS#1 PEM parses and exposes p/q with p*q == n", async () => {
  const fixture = await pemFixtures();
  const imported = await importPem(fixture.pkcs1Pem);
  assert.equal(imported.material.p?.length, 128);
  assert.equal(imported.material.q?.length, 128);
  const n = b64uToBigint(imported.publicJwk.n);
  const p = bytesToBigint(imported.material.p!);
  const q = bytesToBigint(imported.material.q!);
  assert.equal(p * q, n);
});

test("import: garbage input fails with clean message, no echo of input", async () => {
  let message = "";
  try {
    await importPem("this is not a pem");
  } catch (err) {
    message = err instanceof Error ? err.message : String(err);
  }
  assert.match(message, /no PEM block found/);
  assert.ok(!message.includes("this is not"));
});

test("import: encrypted PEM without passphrase asks for one", async () => {
  const armored = await exportEncryptedPem({ der: (await pemFixtures()).pkcs8Der }, "twelve-chars");
  await assert.rejects(importPem(armored.replace(/Iterations: \d+/, "Iterations: 600000")), /passphrase/i);
});

// --- export-enc ----------------------------------------------------------------

test("export-enc: armored roundtrip recovers identical DER", async () => {
  const der = randomBytes(512);
  const armored = await exportEncryptedPem({ der }, "passphrase-123");
  assert.match(armored, /-----BEGIN GUARDTALK ENCRYPTED KEY-----/);
  assert.match(armored, /KDF: PBKDF2-SHA256/);
  assert.match(armored, /Iterations: 600000/);
  const back = await decryptEncryptedPem(armored, "passphrase-123");
  assert.deepEqual([...back.der], [...der]);
  zeroise(back.der);
});

test("export-enc: wrong passphrase fails cleanly WITHOUT leaking material", async () => {
  const secret = utf8("TOPSECRET-DER-BYTES-0123456789abcdef");
  const armored = await exportEncryptedPem({ der: secret }, "right pass12");
  let message = "";
  try {
    await decryptEncryptedPem(armored, "wrong pass");
    assert.fail("expected KeyExportError");
  } catch (err) {
    assert.ok(err instanceof KeyExportError);
    message = err.message;
  }
  assert.match(message, /wrong passphrase or corrupted/);
  assert.ok(!message.includes("TOPSECRET"));
  // The REAL passphrase must never appear ("wrong passphrase" wording may).
  assert.ok(!message.includes("right pass12"));
  assert.ok(!armored.includes("TOPSECRET"));
});

test("export-enc: passphrase shorter than 12 characters is refused", async () => {
  const der = randomBytes(32);
  await assert.rejects(
    exportEncryptedPem({ der }, "short"),
    (err: unknown) =>
      err instanceof KeyExportError &&
      err.message.includes(String(PASSPHRASE_MIN_LENGTH)),
  );
});

test("export-enc: iteration floor is enforced on decrypt side", async () => {
  const der = randomBytes(64);
  const armored = await exportEncryptedPem({ der }, "twelve-chars");
  const tampered = armored.replace(/Iterations: 600000/, "Iterations: 1000");
  await assert.rejects(decryptEncryptedPem(tampered, "twelve-chars"), /iteration count below policy/);
});

// --- zeroise ---------------------------------------------------------------------

test("zeroise: actually zeroes buffers in place; scrub clears object fields", () => {
  const buf = utf8("sensitive-bytes");
  const sameRef = zeroise(buf);
  assert.equal(sameRef, buf);
  assert.ok(buf.every((b) => b === 0));

  const obj = { secret: utf8("leak-me"), note: "hello" };
  scrub(obj);
  assert.ok(obj.secret.every((b) => b === 0));
  assert.equal(obj.note, "");
});

test("pagehide hook: installs and uninstalls cleanly when window exists", { skip: typeof window === "undefined" }, () => {
  let called = 0;
  const uninstall = onPageHide(() => {
    called += 1;
  });
  uninstall();
});

// --- key-leak scan (source-text assertions over lib/keys/*.ts) --------------------

const SINK_PATTERNS: [string, RegExp][] = [
  ["fetch(", /\bfetch\s*\(/],
  ["XMLHttpRequest", /\bXMLHttpRequest\b/],
  ["WebSocket", /\bWebSocket\b/],
  ["localStorage/sessionStorage write", /\.(local|session)Storage\.setItem\b/],
  ["document.cookie", /document\.cookie/],
  ["location.href assignment", /location\.href\s*=/],
  ["console/log sink", /console\.(log|info|debug|error|warn)\s*\(/],
];

test("key-leak scan: no sinks reachable from lib/keys sources", () => {
  const dir = fileURLToPath(new URL("../lib/keys/", import.meta.url));
  const files = ["generate.ts", "import.ts", "export-enc.ts", "fingerprint.ts", "zeroise.ts"];
  for (const file of files) {
    const src = readFileSync(`${dir}${file}`, "utf8");
    for (const [sink, pattern] of SINK_PATTERNS) {
      assert.equal(pattern.test(src), false, `${file} contains forbidden sink ${sink} (D-007)`);
    }
    assert.equal(/\bnew URL\(/.test(src), false, `${file} constructs URLs`);
  }
});

// --- pkmd parity anchor -----------------------------------------------------------

test("pkmd parity anchor: keys fingerprint matches lib/avb encoding for fixed vector", async () => {
  const jwk = fixedJwk();
  const n = b64uToBigint(jwk.n);
  const pkmd = encodePkmd({ n, e: 65537n });
  const viaKeys = await fingerprintFromJwk(jwk);
  const direct = await pkmdFingerprint(pkmd);
  assert.equal(viaKeys, direct);
});

// --- helpers ----------------------------------------------------------------------

interface RsaAlgorithm {
  name: string;
  modulusLength: number;
}

/**
 * Deterministic 1024-bit RSA public vector, generated in-code (no hand-typed
 * base64 to get wrong): the modulus is a fixed odd integer ≥ 2^1023 built
 * from a bit pattern, encoded to base64url at runtime. encodePkmd only needs
 * bitLength(n) to be a multiple of 8 (≥ 2048) and e = 65537 — it never
 * factors n, so any fixed odd wide integer is a valid vector.
 */
function fixedJwk(eInput?: number): JsonWebKey {
  return {
    kty: "RSA",
    alg: "RS256",
    ext: true,
    n: b64uEncode(FIXED_MODULUS_BYTES()),
    e: b64uEncode(bigIntToBytes(BigInt(eInput ?? 65537))),
  };
}

/** 4096-bit fixed odd modulus with top bit set (deterministic, never random). */
function FIXED_MODULUS_BYTES(): Uint8Array {
  const out = new Uint8Array(512);
  const pattern = utf8("GuardTalkOS-fixed-RSA-vector-2026-08-22::do-not-use-operationally");
  for (let i = 0; i < out.length; i += 1) {
    out[i] = pattern[i % pattern.length]!;
  }
  out[0]! |= 0x80; // force top bit: bitLength == 4096
  out[511]! |= 0x01; // odd
  return out;
}

interface PemFixtures {
  publicKey: CryptoKey;
  pkcs8Der: Uint8Array;
  pkcs8Pem: string;
  pkcs1Pem: string;
}

let fixturePromise: Promise<PemFixtures> | undefined;

/** One extractable RSA-2048 twin per run; all PEM variants derive from it. */
function pemFixtures(): Promise<PemFixtures> {
  if (fixturePromise === undefined) {
    fixturePromise = buildPemFixtures();
  }
  return fixturePromise;
}

async function buildPemFixtures(): Promise<PemFixtures> {
  const pair = await crypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", modulusLength: 2048, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
    true,
    ["sign", "verify"],
  );
  const pkcs8Der = new Uint8Array(await crypto.subtle.exportKey("pkcs8", pair.privateKey));
  return {
    publicKey: pair.publicKey,
    pkcs8Der,
    pkcs8Pem: pemText("PRIVATE KEY", pkcs8Der),
    pkcs1Pem: pemText("RSA PRIVATE KEY", stripPkcs8Wrapper(pkcs8Der)),
  };
}

/** PKCS#8 → PKCS#1: drop SEQUENCE(version, algId, OCTET STRING) wrapper. */
function stripPkcs8Wrapper(pkcs8: Uint8Array): Uint8Array {
  const [version, algId, inner] = children(pkcs8, seqAt(pkcs8, 0));
  void version;
  void algId;
  return valueBytes(pkcs8, inner);
}

function pemText(label: string, der: Uint8Array): string {
  const encoded = b64Encode(der).replace(/(.{64})/g, "$1\n").trimEnd();
  return `-----BEGIN ${label}-----\n${encoded}\n-----END ${label}-----\n`;
}

function normalizeJwk(jwk: JsonWebKey): string {
  return JSON.stringify({ kty: jwk.kty, n: jwk.n, e: jwk.e });
}

// --- byte helpers -------------------------------------------------------------------

function randomBytes(length: number): Uint8Array {
  const out = new Uint8Array(length);
  crypto.getRandomValues(out);
  return out;
}

function utf8(text: string): Uint8Array {
  return new TextEncoder().encode(text);
}

function bigIntToBytes(value: bigint): Uint8Array {
  let hex = value.toString(16);
  if (hex.length % 2 === 1) {
    hex = `0${hex}`;
  }
  const out = new Uint8Array(hex.length / 2);
  for (let i = 0; i < out.length; i += 1) {
    out[i] = Number.parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  }
  return out;
}

function bytesToBigint(bytes: Uint8Array): bigint {
  let hex = "";
  for (const b of bytes) {
    hex += b.toString(16).padStart(2, "0");
  }
  return BigInt(`0x${hex}`);
}

function b64uToBigint(b64url: string | undefined): bigint {
  if (b64url === undefined) {
    assert.fail("JWK field missing");
  }
  return bytesToBigint(b64uDecode(b64url));
}

function b64uDecode(value: string): Uint8Array {
  const normalized = value.replace(/-/g, "+").replace(/_/g, "/");
  const padded = normalized + "=".repeat((4 - (normalized.length % 4)) % 4);
  const binary = atob(padded);
  const out = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    out[i] = binary.charCodeAt(i);
  }
  return out;
}

function b64uEncode(bytes: Uint8Array): string {
  return b64Encode(bytes).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

function b64Encode(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) {
    binary += String.fromCharCode(b);
  }
  return btoa(binary);
}

async function sha256HexOf(data: Uint8Array): Promise<string> {
  const digest = await crypto.subtle.digest("SHA-256", data);
  return [...new Uint8Array(digest)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

// Minimal DER reading (mirrors the walker in lib/keys/import.ts).

interface Tlv {
  tag: number;
  valueOffset: number;
  valueLength: number;
}

function seqAt(buf: Uint8Array, offset: number): Tlv {
  const tlv = tlvAt(buf, offset);
  assert.equal(tlv.tag, 0x30, "expected DER SEQUENCE");
  return tlv;
}

function tlvAt(buf: Uint8Array, offset: number): Tlv {
  const tag = buf[offset]!;
  const firstLen = buf[offset + 1]!;
  let lenOff = offset + 2;
  let length = firstLen;
  if ((firstLen & 0x80) !== 0) {
    const numBytes = firstLen & 0x7f;
    length = 0;
    for (let i = 0; i < numBytes; i += 1) {
      length = length * 256 + buf[lenOff]!;
      lenOff += 1;
    }
  }
  return { tag, valueOffset: lenOff, valueLength: length };
}

function children(buf: Uint8Array, tlv: Tlv): [Tlv, Tlv, Tlv] {
  const out: Tlv[] = [];
  let off = tlv.valueOffset;
  while (off < tlv.valueOffset + tlv.valueLength) {
    const child = tlvAt(buf, off);
    out.push(child);
    off = child.valueOffset + child.valueLength;
  }
  assert.equal(out.length, 3);
  return out as [Tlv, Tlv, Tlv];
}

function valueBytes(buf: Uint8Array, tlv: Tlv): Uint8Array {
  return buf.slice(tlv.valueOffset, tlv.valueOffset + tlv.valueLength);
}
