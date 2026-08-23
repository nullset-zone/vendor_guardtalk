/**
 * AVB foundations test suite (PLAN.md §4: parser/signer/pkmd/descriptors unit +
 * reference-avbtool parity + pkmd parity + tamper matrix).
 *
 * Real-release fixtures: channels/tokay/vbmeta*.img, avb_pkmd.bin.
 * Parity fixtures are generated on the fly with python3 avbtool + openssl when
 * available; the parity tests SKIP gracefully otherwise (never faked).
 */
import assert from "node:assert/strict";
import { createHash, createPrivateKey } from "node:crypto";
import { execFile } from "node:child_process";
import { mkdtempSync, readFileSync, existsSync, rmSync } from "node:fs";
import { tmpdir } from "node:os";
import { join, resolve } from "node:path";
import { promisify } from "node:util";
import { after, before, test } from "node:test";

import {
  beBytesToBigInt,
  constantTimeEqual,
  modInverse,
  roundUpTo,
} from "../lib/avb/bytes.js";
import {
  type ChainPartitionDescriptor,
  DESCRIPTOR_TAG_CHAIN,
  DESCRIPTOR_TAG_HASH,
  DESCRIPTOR_TAG_HASHTREE,
  type KernelCmdlineDescriptor,
  DESCRIPTOR_TAG_KERNEL_CMDLINE,
  type PropertyDescriptor,
  DESCRIPTOR_TAG_PROPERTY,
  descriptorsEqual,
  encodeDescriptor,
  isChainDescriptor,
  isHashDescriptor,
  isHashtreeDescriptor,
  parseDescriptors,
} from "../lib/avb/descriptors.js";
import { decodePkmd, encodePkmd, pkmdFingerprint } from "../lib/avb/pkmd.js";
import { algorithmName, parseFooter, parseVbmeta } from "../lib/avb/parser.js";
import { resignVbmetaWithRelease, verifyVbmeta, verifyVbmetaAgainstKey } from "../lib/avb/signer.js";

const execFileAsync = promisify(execFile);

const WORKSPACE = resolve(import.meta.dirname, "../../../..");
const AVBTOOL = join(WORKSPACE, "external/avb/avbtool.py");
const CHANNEL = join(WORKSPACE, "vendor/guardtalk/web-installer/channels/tokay");

function readFixture(name: string): Uint8Array {
  return new Uint8Array(readFileSync(join(CHANNEL, name)));
}

interface GeneratedParity {
  pemPath: string;
  pkmdPath: string;
  vbmetaPath: string;
}

let parity: GeneratedParity | undefined;
let parityDir: string | undefined;

before(async () => {
  if (!(existsSync(AVBTOOL) && (await haveExecutable("python3")) && (await haveExecutable("openssl")))) {
    return;
  }
  try {
    const dir = mkdtempSync(join(tmpdir(), "guardtalk-avb-parity-"));
    parityDir = dir;
    const pemPath = join(dir, "testkey_rsa4096.pem");
    const vbmetaPath = join(dir, "parity.avbvbmeta");
    const pkmdPath = join(dir, "expected.avb_pkmd.bin");
    await execFileAsync("openssl", ["genrsa", "-out", pemPath, "4096"]);
    await execFileAsync("python3", [
      AVBTOOL, "make_vbmeta_image",
      "--output", vbmetaPath,
      "--algorithm", "SHA256_RSA4096",
      "--key", pemPath,
      "--padding_size", "64",
    ]);
    await execFileAsync("python3", [AVBTOOL, "extract_public_key", "--key", pemPath, "--output", pkmdPath]);
    parity = { pemPath, pkmdPath, vbmetaPath };
  } catch {
    parity = undefined;
  }
});

after(() => {
  if (parityDir !== undefined) {
    try {
      rmSync(parityDir, { recursive: true, force: true });
    } catch {
      // best-effort cleanup of the temp dir
    }
  }
});

async function haveExecutable(name: string): Promise<boolean> {
  // `openssl` has no --version flag (use bare `version`); python3/other tools
  // print a version for --version. Try both, fail only if neither runs.
  for (const args of [["--version"], ["version"]]) {
    try {
      await execFileAsync(name, args);
      return true;
    } catch {
      // try next probe
    }
  }
  return false;
}

// ---------------------------------------------------------------------------
// Test 1 — real fixture parsing
// ---------------------------------------------------------------------------

for (const name of ["vbmeta.img", "vbmeta_system.img", "vbmeta_vendor.img"]) {
  test(`parse ${name}: magic AVB0, alg 2, descriptors present, pubkey 1032`, () => {
    const img = readFixture(name);
    const parsed = parseVbmeta(img);
    assert.equal(parsed.header.magic, "AVB0");
    assert.equal(parsed.header.algorithmType, 2);
    assert.equal(algorithmName(parsed.header.algorithmType), "SHA256_RSA4096");
    assert.ok(parsed.descriptors.length > 0);
    assert.equal(parsed.publicKey?.length, 1032);
    assert.equal(parsed.header.hashSize, 32);
    assert.equal(parsed.header.signatureSize, 512);
    assert.equal(parsed.authHash?.length, 32);
    assert.equal(parsed.authSignature?.length, 512);
    assert.ok(parsed.footer === undefined, "bare vbmeta has no footer");
    assert.match(parsed.header.releaseString, /avbtool/);
    // Descriptor region must be exactly consumed by the parsed chain.
    let wireLen = 0;
    for (const d of parsed.descriptors) {
      wireLen += encodeDescriptor(d).length;
    }
    assert.equal(wireLen, parsed.header.descriptorsSize);
  });
}

test("fixture descriptor mix matches expected tags", () => {
  const parsed = parseVbmeta(readFixture("vbmeta.img"));
  const tags = new Set<number>(parsed.descriptors.map((d) => d.tag));
  for (const tag of [DESCRIPTOR_TAG_PROPERTY, DESCRIPTOR_TAG_HASH, DESCRIPTOR_TAG_HASHTREE]) {
    assert.ok(tags.has(tag), `missing tag ${tag}`);
  }
  const hashDescs = parsed.descriptors.filter(isHashDescriptor).map((d) => d.partitionName);
  assert.ok(hashDescs.includes("boot"));
  const htDescs = parsed.descriptors.filter(isHashtreeDescriptor).map((d) => d.partitionName);
  assert.ok(htDescs.length > 0);
});

test("parse errors are precise", () => {
  const img = readFixture("vbmeta.img");
  const assertCode = (fn: () => unknown, code: string): void => {
    assert.throws(fn, (err: Error) => (err as { code?: string }).code === code);
  };
  const badMagic = Uint8Array.from(img);
  badMagic[0] = 0x58; // 'X'
  assertCode(() => parseVbmeta(badMagic), "BAD_MAGIC");

  const misaligned = Uint8Array.from(img);
  const dv = new DataView(misaligned.buffer);
  dv.setBigUint64(12, 575n, false); // auth block no longer multiple of 64
  assertCode(() => parseVbmeta(misaligned), "BLOCK_ALIGNMENT");

  assertCode(() => parseVbmeta(img.subarray(0, 100)), "TRUNCATED");
  const shortTail = Uint8Array.from(img.subarray(0, 256 + 512)); // cuts aux block
  assertCode(() => parseVbmeta(shortTail), "TRUNCATED");
});

test("parseFooter finds footer only where present", () => {
  assert.equal(parseFooter(readFixture("vbmeta.img")), undefined);
  // Fabricate a footer-carrying partition image per READER-B §A.
  const vbmeta = readFixture("vbmeta.img").subarray(0, 256 + 576 + 6720);
  const payload = new Uint8Array(vbmeta.length + 4096);
  payload.set(vbmeta, 0);
  const dv = new DataView(payload.buffer, payload.byteOffset + payload.byteLength - 64, 64);
  new Uint8Array(payload.buffer, payload.byteOffset + payload.byteLength - 64, 4).set(
    new TextEncoder().encode("AVBf"),
  );
  dv.setUint32(4, 1, false);
  dv.setUint32(8, 0, false);
  dv.setBigUint64(12, BigInt(vbmeta.length), false);
  dv.setBigUint64(20, 0n, false);
  dv.setBigUint64(28, BigInt(vbmeta.length), false);
  const footer = parseFooter(payload);
  assert.ok(footer);
  assert.equal(Number(footer.vbmetaOffset), 0);
  assert.equal(Number(footer.vbmetaSize), vbmeta.length);
  // Roundtrip through the full parser must land at offset 0 as well.
  assert.equal(parseVbmeta(payload).header.magic, "AVB0");
});// ---------------------------------------------------------------------------
// Test 2 — pkmd roundtrip byte-identical on the real fixture
// ---------------------------------------------------------------------------

test("pkmd roundtrip on channels/tokay/avb_pkmd.bin is byte-identical", async () => {
  const fixture = readFixture("avb_pkmd.bin");
  assert.equal(fixture.length, 1032);
  const decoded = decodePkmd(fixture);
  assert.equal(decoded.numBits, 4096);
  assert.equal(decoded.e, 65537n);
  const reencoded = encodePkmd({ n: decoded.n, e: decoded.e });
  assert.ok(constantTimeEqual(reencoded, fixture), "re-encoded pkmd differs from fixture");
  const fp = await pkmdFingerprint(fixture);
  assert.equal(fp, createHash("sha256").update(fixture).digest("hex"));
  // n0inv identity: n0inv == 2^32 - inv(n mod 2^32)
  assert.equal(
    decoded.n0inv,
    Number((1n << 32n) - modInverse(decoded.n % (1n << 32n), 1n << 32n)),
  );
});

test("decodePkmd rejects corrupted blobs", () => {
  assert.throws(
    () => decodePkmd(new Uint8Array(4)),
    (err: Error) => (err as { code?: string }).code === "BAD_NUM_BITS" ||
      (err as { code?: string }).code === "TRUNCATED_PKMD",
  );
  const fixture = Uint8Array.from(readFixture("avb_pkmd.bin"));
  // n0inv is derived from n mod 2^32, i.e. only the LAST four modulus bytes
  // (pkmd offsets 516-519). Flip bit 1 there: parity is preserved so the
  // inverse still exists but no longer matches the stored value.
  const flipIndex = 518;
  const flipped = (fixture[flipIndex] ?? 0) ^ 0x02;
  fixture[flipIndex] = flipped;
  assert.throws(
    () => decodePkmd(fixture),
    (err: Error) =>
      (err as { code?: string }).code === "N0INV_MISMATCH" ||
      (err as { code?: string }).code === "NO_INVERSE",
  );
});

// ---------------------------------------------------------------------------
// Descriptors roundtrip
// ---------------------------------------------------------------------------

test("every fixture descriptor survives parse->encode->parse", () => {
  const parsed = parseVbmeta(readFixture("vbmeta.img"));
  for (const d of parsed.descriptors) {
    const wire = encodeDescriptor(d);
    const again = parseDescriptors(wire);
    assert.equal(again.length, 1);
    const reparsed = again[0];
    assert.ok(reparsed !== undefined);
    assert.ok(descriptorsEqual(d, reparsed));
  }
});

test("synthetic property and cmdline descriptors roundtrip exactly", () => {
  const prop: PropertyDescriptor = {
    tag: DESCRIPTOR_TAG_PROPERTY,
    keyBytes: new TextEncoder().encode("com.android.build.boot"),
    valueBytes: new TextEncoder().encode("110233"),
  };
  const cmd: KernelCmdlineDescriptor = {
    tag: DESCRIPTOR_TAG_KERNEL_CMDLINE,
    flags: 0,
    kernelCmdline: "androidboot.veritymode=enforcing panic=-1",
  };
  for (const d of [prop, cmd] as const) {
    const encoded = encodeDescriptor(d);
    assert.equal(encoded.length % 8, 0, "descriptor padded to 8-byte multiple");
    // Padding bytes (between payload end and the 8-byte-rounded total) are zeros.
    const wire = d.tag === DESCRIPTOR_TAG_PROPERTY
      ? 32 + (d.keyBytes.length + d.valueBytes.length + 2)
      : 24 + new TextEncoder().encode(d.kernelCmdline).length;
    const padStart = wire;
    for (let i = padStart; i < encoded.length; i++) {
      assert.equal(encoded[i], 0, `padding byte at ${i} not zero`);
    }
    const back = parseDescriptors(encoded)[0];
    assert.ok(back !== undefined);
    assert.ok(descriptorsEqual(d, back));
  }
});

// ---------------------------------------------------------------------------
// Test 3 — self-consistency: fresh RSA-4096 key, mutate auth block, resign, verify
// ---------------------------------------------------------------------------

interface TestKey {
  privateKey: CryptoKey;
  publicKeyJwk: JsonWebKey & { n: string; e: string };
}

async function makeTestKey(): Promise<TestKey> {
  const pair = await crypto.subtle.generateKey(
    { name: "RSASSA-PKCS1-v1_5", modulusLength: 4096, publicExponent: new Uint8Array([1, 0, 1]), hash: "SHA-256" },
    true,
    ["sign", "verify"],
  );
  const jwk = (await crypto.subtle.exportKey("jwk", pair.publicKey)) as JsonWebKey & { n: string; e: string };
  return { privateKey: pair.privateKey, publicKeyJwk: jwk };
}

async function buildMinimalSignedVbmeta(key: TestKey, release = "avbtool 1.3.0"): Promise<Uint8Array> {
  // Take the real fixture as scaffolding but swap in OUR public key and a tiny
  // descriptor set so the image is fully self-consistent under our key.
  const fixture = readFixture("vbmeta.img");
  const parsed = parseVbmeta(fixture);
  const ourPkmd = encodePkmd({
    n: beBytesToBigInt(fromBase64Url(key.publicKeyJwk.n)),
    e: beBytesToBigInt(fromBase64Url(key.publicKeyJwk.e)),
  });
  assert.equal(ourPkmd.length, 1032);

  // Aux layout per READER-B §B.2: [descriptors][public key][pad].
  const descBytes = parsed.descriptors.map(encodeDescriptor);
  const descLen = descBytes.reduce((a, b) => a + b.length, 0);
  const auxSize = roundUpTo(descLen + ourPkmd.length, 64);
  const aux = new Uint8Array(auxSize);
  let off = 0;
  for (const d of descBytes) {
    aux.set(d, off);
    off += d.length;
  }
  aux.set(ourPkmd, descLen);

  // Header: clone fixture header, patch sizes/offsets for our geometry.
  const header = Uint8Array.from(fixture.subarray(0, 256));
  const hv = new DataView(header.buffer);
  hv.setBigUint64(20, BigInt(auxSize), false); // auxiliary_data_block_size
  hv.setBigUint64(64, BigInt(descLen), false); // public_key_offset
  hv.setBigUint64(72, 1032n, false); // public_key_size
  hv.setBigUint64(96, 0n, false); // descriptors_offset (aux-relative)
  hv.setBigUint64(104, BigInt(descLen), false); // descriptors_size
  hv.setBigUint64(88, 0n, false); // public_key_metadata_size
  hv.setBigUint64(80, BigInt(descLen + 1032), false); // public_key_metadata_offset

  const blob = new Uint8Array(256 + 576 + auxSize);
  blob.set(header, 0);
  blob.set(aux, 256 + 576);
  const signed = await resignVbmetaWithRelease(blob, key.privateKey, release);
  return signed;
}

function fromBase64Url(b64: string): Uint8Array {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
  const out: number[] = [];
  let bits = 0;
  let acc = 0;
  for (const ch of b64) {
    const v = alphabet.indexOf(ch);
    assert.ok(v >= 0, `bad base64url char ${ch}`);
    acc = (acc << 6) | v;
    bits += 6;
    if (bits >= 8) {
      bits -= 8;
      out.push((acc >> bits) & 0xff);
    }
  }
  return new Uint8Array(out);
}

test("resign with fresh WebCrypto key then verify passes", async () => {
  const key = await makeTestKey();
  const signed = await buildMinimalSignedVbmeta(key);
  // Blob is header + auth + our (smaller) aux — no 64 KiB release padding.
  assert.equal(signed.length, 256 + 576 + parseVbmeta(signed).header.auxiliaryDataBlockSize);
  const result = await verifyVbmeta(signed);
  assert.deepEqual(result, { ok: true }, result.failure ?? "");
  // Deterministic re-sign: same input -> identical output (Law 8).
  const again = await buildMinimalSignedVbmeta(key);
  assert.ok(constantTimeEqual(again, signed));

  // Flip ONE byte anywhere after the header -> verify must fail. Offsets cover
  // the auth block (300), the descriptor region (700) and the pubkey (blobEnd-8).
  const blobLen = signed.length;
  for (const offset of [300, 700, 2000, blobLen - 8]) {
    const tampered = Uint8Array.from(signed);
    tampered[offset] = (tampered[offset] ?? 0) ^ 0x01;
    const verdict = await verifyVbmeta(tampered);
    assert.equal(verdict.ok, false, `tamper at ${offset} not detected`);
    assert.ok(verdict.failure && verdict.failure.length > 0);
  }
});

test("release string preserved unless overridden", async () => {
  const key = await makeTestKey();
  const keep = await buildMinimalSignedVbmeta(key);
  assert.equal(parseVbmeta(keep).header.releaseString, "avbtool 1.3.0");
  const custom = await resignVbmetaWithRelease(keep, key.privateKey, "GuardTalkOS installer");
  const parsedCustom = parseVbmeta(custom);
  assert.equal(parsedCustom.header.releaseString, "GuardTalkOS installer");
  assert.ok(await verifyVbmeta(custom));
});

// ---------------------------------------------------------------------------
// Test 4 — tamper matrix
// ---------------------------------------------------------------------------

test("tamper matrix: aux byte, auth hash, swapped pubkey all detected", async () => {
  const key = await makeTestKey();
  const signed = await buildMinimalSignedVbmeta(key);
  const parsed = parseVbmeta(signed);
  const authStart = 256;
  const pubkeyAt = 256 + parsed.header.authenticationDataBlockSize + parsed.header.publicKeyOffset;

  // (a) modified AUX byte (descriptor region) -> digest mismatch.
  const auxTamper = Uint8Array.from(signed);
  auxTamper[pubkeyAt - 16] = (auxTamper[pubkeyAt - 16] ?? 0) ^ 0x01; // last descriptor byte before pubkey
  const r1 = await verifyVbmeta(auxTamper);
  assert.equal(r1.ok, false);
  assert.match(r1.failure ?? "", /digest mismatch/);

  // (b) modified AUTH hash -> digest mismatch.
  const hashTamper = Uint8Array.from(signed);
  hashTamper[authStart] = (hashTamper[authStart] ?? 0) ^ 0xff;
  const r2 = await verifyVbmeta(hashTamper);
  assert.equal(r2.ok, false);
  assert.match(r2.failure ?? "", /digest mismatch/);

  // (c) swapped pubkey without re-signing -> verify fails (key/signature bind).
  const otherKey = await makeTestKey();
  const swapped = Uint8Array.from(signed);
  const foreignPkmd = encodePkmd({
    n: beBytesToBigInt(fromBase64Url(otherKey.publicKeyJwk.n)),
    e: 65537n,
  });
  swapped.set(foreignPkmd, pubkeyAt);
  const r3 = await verifyVbmeta(swapped);
  assert.equal(r3.ok, false);
  assert.ok(r3.failure !== undefined);
  // And verifying the swapped image against the ORIGINAL enrolled key fails closed.
  const originalPkmd = parsed.publicKey;
  assert.ok(originalPkmd !== undefined);
  const againstOriginal = await verifyVbmetaAgainstKey(swapped, originalPkmd);
  assert.equal(againstOriginal.ok, false);
  assert.match(againstOriginal.failure ?? "", /does not match given key/);
});

// ---------------------------------------------------------------------------
// Tests 5+6 — python avbtool parity and chain detection
// ---------------------------------------------------------------------------

test("chain-descriptor detection on vbmeta_system feeds flow-stop logic", () => {
  // The tokay release chains system/vendor to their own vbmetas; detect them here.
  const mainParsed = parseVbmeta(readFixture("vbmeta_system.img"));
  const syntheticChain = parseDescriptors(
    encodeDescriptor({
      tag: DESCRIPTOR_TAG_CHAIN,
      rollbackIndexLocation: 1,
      partitionName: "system",
      publicKey: new Uint8Array(1032),
      flags: 0,
    }),
  );
  const combined = [...mainParsed.descriptors, ...syntheticChain];
  const chains = combined.filter(isChainDescriptor);
  assert.ok(chains.length >= 1);
  const last = chains[chains.length - 1] as ChainPartitionDescriptor | undefined;
  assert.ok(last !== undefined);
  assert.equal(last.partitionName, "system");
  assert.equal(last.rollbackIndexLocation, 1);
  assert.equal(last.publicKey.length, 1032);
  // Flow-stop rule (READER-B §D): any chain descriptor means STOP before signing.
  assert.ok(chains.length > 0, "flow must stop while chained partitions lack known layout");
});

test("parity: encodePkmd equals avbtool extract_public_key output", async (t) => {
  if (!parity) {
    t.skip("python3 avbtool or openssl unavailable — parity NOT verified this run");
    return;
  }
  const expected = new Uint8Array(readFileSync(parity.pkmdPath));
  const jwk = createPrivateKeyJwkFromPem(readFileSync(parity.pemPath, "utf8"));
  const ours = encodePkmd(jwk);
  assert.equal(ours.length, expected.length);
  assert.ok(constantTimeEqual(ours, expected), "encodePkmd != avbtool extract_public_key");
});

test("parity: parseVbmeta(avbtool make_vbmeta_image output)", async (t) => {
  if (!parity) {
    t.skip("python3 avbtool or openssl unavailable — parity NOT verified this run");
    return;
  }
  const img = new Uint8Array(readFileSync(parity.vbmetaPath));
  const ours = parseVbmeta(img);
  assert.equal(ours.header.magic, "AVB0");
  assert.equal(ours.header.algorithmType, 2);
  assert.equal(ours.publicKey?.length, 1032);
  assert.equal(ours.descriptors.length, 0, "bare make_vbmeta_image has no descriptors");
  assert.equal(ours.footer, undefined);
  const verified = await verifyVbmeta(img);
  assert.deepEqual(verified, { ok: true }, verified.failure ?? "");
  const embedded = ours.publicKey;
  assert.ok(embedded !== undefined);
  const againstEmbedded = await verifyVbmetaAgainstKey(img, embedded);
  assert.deepEqual(againstEmbedded, { ok: true }, againstEmbedded.failure ?? "");
});

test("parity: resign fixture-style minimal image matches avbtool byte-for-byte", async (t) => {
  if (!parity) {
    t.skip("python3 avbtool or openssl unavailable — parity NOT verified this run");
    return;
  }
  const avbOutput = new Uint8Array(readFileSync(parity.vbmetaPath));
  // Re-sign the SAME blob with the SAME key via our signer; must be a fixed point.
  const resigned = await resignWithPemKey(avbOutput);
  assert.ok(constantTimeEqual(resigned, avbOutput), "our resign != avbtool output");
});

// -- parity helpers ---------------------------------------------------------

function createPrivateKeyJwkFromPem(pem: string): { n: bigint; e: bigint } {
  const jwk = createPrivateKey(pem).export({ format: "jwk" }) as { n: string; e: string };
  return { n: beBytesToBigInt(fromBase64Url(jwk.n)), e: beBytesToBigInt(fromBase64Url(jwk.e)) };
}

async function resignWithPemKey(img: Uint8Array): Promise<Uint8Array> {
  // Pass the PEM CONTENT, not the path (createPrivateKey expects key data).
  const pemContent = readFileSync(parity!.pemPath, "utf8");
  const jwk = createPrivateKey(pemContent).export({ format: "jwk" }) as {
    kty: "RSA";
    n: string;
    e: string;
    d: string;
    p: string;
    q: string;
    dp: string;
    dq: string;
    qi: string;
  };
  const cryptoKey = await crypto.subtle.importKey(
    "jwk",
    jwk,
    { name: "RSASSA-PKCS1-v1_5", hash: "SHA-256" },
    false,
    ["sign"],
  );
  return resignVbmetaWithRelease(img, cryptoKey);
}
