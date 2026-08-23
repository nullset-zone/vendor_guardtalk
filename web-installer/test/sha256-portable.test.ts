import assert from "node:assert/strict";
import { createHash } from "node:crypto";
import { test } from "node:test";
import { sha256Hex } from "../src/hash.js";
import { sha256PortableHex } from "../src/sha256-portable.js";
import { utf8 } from "./helpers.js";

function nodeSha256(data: Uint8Array): string {
  return createHash("sha256").update(data).digest("hex");
}

test("portable SHA-256 matches FIPS empty and abc vectors", () => {
  assert.equal(
    sha256PortableHex(utf8("")),
    "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855",
  );
  assert.equal(
    sha256PortableHex(utf8("abc")),
    "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad",
  );
});

test("portable SHA-256 matches node:crypto on fixture bytes", () => {
  const samples = [utf8("public-avb-pkmd"), utf8("bl-tokay-v1"), new Uint8Array(1024)];
  for (const sample of samples) {
    assert.equal(sha256PortableHex(sample), nodeSha256(sample));
    assert.equal(sha256Hex(sample), nodeSha256(sample));
  }
});
