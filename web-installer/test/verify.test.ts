import assert from "node:assert/strict";
import { createHash, generateKeyPairSync, sign as nodeSign } from "node:crypto";
import { test } from "node:test";
import { armoredPemToJwk, verifyDetached, type RsaPublicJwk } from "../lib/verify/detached-sig.js";
import { compareExact, compareHex, formatSideBySide, truncateMiddle, verdictWord } from "../lib/verify/side-by-side.js";
import { hexEqual, parseSha256Sums, Sha256Sums } from "../lib/verify/sums.js";

const DIGEST_A = createHash("sha256").update("guardtalk-alpha").digest("hex");
const DIGEST_B = createHash("sha256").update("tokay-release").digest("hex");

function sumsText(): string {
  return [
    "# GuardTalkOS alpha",
    `${DIGEST_A}  guardtalk-os-installer.zip`,
    `${DIGEST_B} *vbmeta.img`,
  ].join("\n");
}

test("valid SHA256SUMS parses, incl. binary marker and comments", () => {
  const parsed = parseSha256Sums(sumsText());
  assert.equal(parsed.size, 2);
  assert.equal(parsed.digestFor("guardtalk-os-installer.zip"), DIGEST_A);
  const binaryEntry = parsed.lookup("vbmeta.img");
  assert.ok(binaryEntry !== undefined);
  assert.equal(binaryEntry.binaryMarker, true);
  assert.equal(binaryEntry.line, 3);
});

test("CRLF and BOM tolerance", () => {
  const crlf = parseSha256Sums(`\uFEFF${DIGEST_A}  one.zip\r\n${DIGEST_B} *two.img\r\n`);
  assert.equal(crlf.size, 2);
  const twoSpace = parseSha256Sums(`${DIGEST_A}  one.zip\n${DIGEST_B}  two.img`);
  assert.equal(twoSpace.size, 2);
  const spaceOnly = parseSha256Sums(`${DIGEST_A} one.zip`);
  assert.equal(spaceOnly.lookup("one.zip")?.binaryMarker, false);
});

test("malformed lines report their line number", () => {
  const badDigest = `abc123  short-digest.zip`;
  const missingName = `${DIGEST_A}  `;
  const tabSeparator = `${DIGEST_A}\ttwo-space.zip`;
  for (const [text, line] of [
    [badDigest, 1],
    [`${DIGEST_A}  good.zip\nnot-a-hash-line\n${DIGEST_B}  also-good.zip`, 2],
    [missingName, 1],
    [tabSeparator, 1],
    ["", 0],
    [`${DIGEST_A}  ../escape.zip`, 1],
    [`${DIGEST_A}  key.pem`, 1],
    [`${DIGEST_A}  dup.zip\n${DIGEST_B}  dup.zip`, 2],
  ] as ReadonlyArray<readonly [string, number]>) {
    try {
      parseSha256Sums(text);
      assert.fail(`expected failure for ${JSON.stringify(text)}`);
    } catch (error) {
      const message = String((error as Error).message);
      if (line === 0) {
        assert.doesNotMatch(message, /line \d+/);
      } else {
        assert.match(message, /line \d+/);
        assert.match(message, new RegExp(`line ${line}`));
      }
    }
  }
});

test("empty SHA256SUMS lists no files", () => {
  assert.throws(() => parseSha256Sums("\n\n# only a comment\n"), /lists no files/);
});

test("case-insensitive hex compare helper", () => {
  assert.equal(hexEqual(DIGEST_A.toUpperCase(), DIGEST_A), true);
  assert.equal(hexEqual(DIGEST_A, DIGEST_B), false);
  assert.equal(hexEqual("nothex", DIGEST_A), false);
});

test("Sha256Sums lookup misses cleanly", () => {
  const parsed: Sha256Sums = parseSha256Sums(sumsText());
  assert.equal(parsed.digestFor("missing.zip"), undefined);
  assert.deepEqual(parsed.entries().map((entry) => entry.filename).sort(), ["guardtalk-os-installer.zip", "vbmeta.img"]);
});

test("side-by-side match formatting is stable", () => {
  const match = compareHex(DIGEST_A, DIGEST_A.toUpperCase());
  assert.equal(match.match, true);
  assert.equal(verdictWord(match), "MATCH");
  const formatted = formatSideBySide("release", match);
  assert.match(formatted, /MATCH/);
  assert.match(formatted, /expected/);
  assert.match(formatted, /actual/);
  assert.equal(formatted, formatSideBySide("release", match));
});

test("side-by-side mismatch keeps both values visible", () => {
  const mismatch = compareHex(DIGEST_A, DIGEST_B);
  assert.equal(mismatch.match, false);
  assert.equal(verdictWord(mismatch), "MISMATCH");
  const formatted = formatSideBySide("release", mismatch);
  assert.ok(formatted.includes(truncateMiddle(DIGEST_A.toLowerCase(), 32)));
  assert.ok(formatted.includes(truncateMiddle(DIGEST_B.toLowerCase(), 32)));
});

test("exact comparison model works for product strings", () => {
  assert.equal(compareExact("tokay", "tokay").match, true);
  const mismatch = compareExact("tokay", "akita");
  assert.equal(mismatch.match, false);
  assert.equal(verdictWord(mismatch), "MISMATCH");
});

function pemKeyPair(): { privateKeyPem: string; publicKeyPem: string; jwk: RsaPublicJwk } {
  const { publicKey, privateKey } = generateKeyPairSync("rsa", { modulusLength: 2048 });
  return {
    privateKeyPem: privateKey.export({ type: "pkcs8", format: "pem" }).toString(),
    publicKeyPem: publicKey.export({ type: "spki", format: "pem" }).toString(),
    jwk: publicKey.export({ format: "jwk" }) as RsaPublicJwk,
  };
}

test("detached-sig roundtrip verifies with generated keypair, fails on byte flip", async () => {
  const { privateKeyPem, publicKeyPem, jwk } = pemKeyPair();
  const sums = sumsText();
  const signature = nodeSign("sha256", Buffer.from(sums, "utf8"), privateKeyPem);
  const viaJwk = await verifyDetached(new Uint8Array(signature), sums, jwk);
  assert.deepEqual(viaJwk, { valid: true });
  const viaPemJwk = await armoredPemToJwk(publicKeyPem);
  assert.equal(viaPemJwk.kty, "RSA");
  const roundtrip = await verifyDetached(new Uint8Array(signature), sums, viaPemJwk);
  assert.equal(roundtrip.valid, true);
  const flipped = new Uint8Array(signature);
  const last = flipped.length - 1;
  flipped[last] = (flipped[last] ?? 0) ^ 0x01;
  const tampered = await verifyDetached(flipped, sums, viaPemJwk);
  assert.equal(tampered.valid, false);
  assert.ok(typeof tampered.reason === "string" && tampered.reason.length > 0);
  const tamperedText = await verifyDetached(new Uint8Array(signature), `${sums}X`, viaPemJwk);
  assert.equal(tamperedText.valid, false);
});
