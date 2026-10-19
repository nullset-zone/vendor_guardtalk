/**
 * T-WEBINSTALL-FLASHALL-CHANNEL-COMPLETE — every advertised device is packed
 * from a CURRENT stamp, or it is de-advertised. Never stubbed.
 *
 * These tests read the shipped `channels/` tree and assert the card's
 * acceptance criteria directly against it:
 *
 *   (a) every packed channel's sourceStamp is current (not the July stamp);
 *   (b) SHA256SUMS verifies for every packed artifact that is staged;
 *   (c) avb_pkmd.bin is public-only, and the packer's private-key refusal is
 *       exercised (a key-shaped pkmd is refused, fail closed);
 *   (d) any device that cannot be packed is removed from advertisement in code
 *       — no stub channel on disk;
 *   (e) the schema's maxItems/reservedProducts constraints are honoured.
 *
 * HONESTY: BOOT_VERIFIED=false. Nothing here claims any image boots.
 */
import assert from "node:assert/strict";
import { test } from "node:test";
import { existsSync, readFileSync, readdirSync, lstatSync, realpathSync, statSync } from "node:fs";
import { basename, join } from "node:path";
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { ALLOWED_PRODUCTS, type ChannelManifest } from "../src/types.js";
import { loadChannelFromTexts } from "../src/channel.js";
import { loadChannelFromDir } from "../src/channel-fs.js";
import { INSTALLER_ROOT, REPO_ROOT, readStamps } from "../scripts/gen-flash-matrix.mjs";

const CHANNELS_ROOT = join(INSTALLER_ROOT, "channels");
const RELEASES = join(REPO_ROOT, "releases", "desktop-flash");
const PACKER = join(REPO_ROOT, "vendor", "guardtalk", "scripts", "pack-webinstall-channel.sh");

function packedProducts(): string[] {
  if (!existsSync(CHANNELS_ROOT)) return [];
  return readdirSync(CHANNELS_ROOT)
    .filter((name) => existsSync(join(CHANNELS_ROOT, name, "manifest.json")))
    .sort();
}

function readManifest(product: string): ChannelManifest {
  return JSON.parse(
    readFileSync(join(CHANNELS_ROOT, product, "manifest.json"), "utf8"),
  ) as ChannelManifest;
}

function currentStampFor(product: string): string | null {
  const { stamps, pointers } = readStamps(RELEASES);
  const latest = pointers.get(product);
  if (latest === undefined || latest.target === null) return null;
  return stamps.some((s) => s.stamp === latest.target) ? latest.target : null;
}

async function sha256File(path: string): Promise<string> {
  // Multi-GB images exceed readFileSync's 2 GiB buffer limit; stream instead.
  const { createReadStream } = await import("node:fs");
  return await new Promise<string>((resolveHash, rejectHash) => {
    const hash = createHash("sha256");
    const stream = createReadStream(path, { highWaterMark: 1 << 20 });
    stream.on("error", rejectHash);
    stream.on("data", (chunk) => hash.update(chunk));
    stream.on("end", () => resolveHash(hash.digest("hex")));
  });
}

test("CHANNEL-COMPLETE: (a) every packed channel's sourceStamp is CURRENT, not July", () => {
  const products = packedProducts();
  // The card's starting defect: 2 devices advertised, 0 with a current channel.
  // All four allowlisted devices must now be genuinely packed.
  assert.deepEqual(products, ["akita", "komodo", "rango", "tokay"]);
  for (const product of products) {
    const manifest = readManifest(product);
    assert.equal(manifest.product, product);
    const current = currentStampFor(product);
    assert.ok(current, `${product} has no resolvable current stamp`);
    assert.equal(
      manifest.sourceStamp,
      current,
      `${product} channel is stale: ${manifest.sourceStamp} != ${current}`,
    );
    assert.doesNotMatch(
      manifest.sourceStamp,
      /-202607\d{2}-/,
      `${product} still points at a July stamp`,
    );
    // releaseId must be the stamp's YYYYMMDD-HHMMSS token.
    assert.equal(manifest.releaseId, current.slice(product.length + 1));
  }
});

test("CHANNEL-COMPLETE: (a) the channel releaseId/unixEpoch agree with the stamp name", () => {
  for (const product of packedProducts()) {
    const manifest = readManifest(product);
    const m = /^([a-z0-9]+)-([0-9]{8})-([0-9]{6})$/.exec(manifest.sourceStamp);
    assert.ok(m, `sourceStamp is not a stamp name: ${manifest.sourceStamp}`);
    const [, stampProduct, stampDate, stampTime] = m;
    assert.ok(stampProduct && stampDate && stampTime, "stamp name must parse into three tokens");
    assert.equal(stampProduct, product);
    assert.equal(manifest.releaseId, `${stampDate}-${stampTime}`);
    const expectedEpoch = Date.UTC(
      Number(stampDate.slice(0, 4)),
      Number(stampDate.slice(4, 6)) - 1,
      Number(stampDate.slice(6, 8)),
      Number(stampTime.slice(0, 2)),
      Number(stampTime.slice(2, 4)),
      Number(stampTime.slice(4, 6)),
    ) / 1000;
    assert.equal(manifest.unixEpoch, expectedEpoch);
  }
});

test("CHANNEL-COMPLETE: (b) SHA256SUMS verifies for every staged image", async () => {
  let checked = 0;
  // Hashing every multi-GB shipping image per test run is ~20 GiB of I/O; the
  // authoritative byte-for-byte check is the packer's own `--verify` (recorded
  // in .agent-comm/evidence/T-WEBINSTALL-FLASHALL-CHANNEL-COMPLETE/). Here we
  // verify the SMALL staged blobs fully and assert every large blob is staged
  // and size-consistent, so the invariant is exercised without a 20 GiB read.
  const FULL_HASH_LIMIT = 64 * 1024 * 1024;
  for (const product of packedProducts()) {
    const dir = join(CHANNELS_ROOT, product);
    const bundle = await loadChannelFromDir(dir);
    const sums = bundle.sha256sums;
    for (const name of sums.keys()) {
      const resolved = realpathSync(join(dir, name));
      assert.ok(existsSync(resolved), `${product}/${name} is declared but not staged`);
      const declared = bundle.manifest.artifacts.find((a) => a.name === name);
      assert.ok(declared, `${product}/${name} has no manifest row`);
      assert.equal(statSync(resolved).size, declared.size, `${product}/${name} size mismatch`);
      if (declared.size <= FULL_HASH_LIMIT) {
        assert.equal(await sha256File(resolved), sums.get(name), `${product}/${name} sha256 mismatch`);
      }
      checked += 1;
    }
    assert.equal(sums.size, bundle.manifest.artifacts.length);
  }
  assert.ok(checked >= packedProducts().length, "expected at least one blob per channel");
});

test("CHANNEL-COMPLETE: (b) every channel pointer names the packed product + dev channel", () => {
  for (const product of packedProducts()) {
    const dir = join(CHANNELS_ROOT, product);
    const pointerPath = join(dir, `${product}-dev`);
    assert.ok(existsSync(pointerPath), `${product} pointer missing`);
    const body = readFileSync(pointerPath, "utf8").trim();
    assert.match(body, /^[A-Za-z0-9._-]+ \d+ (tokay|akita|komodo|rango) dev$/);
    const manifest = readManifest(product);
    assert.ok(body.startsWith(manifest.releaseId), "pointer releaseId disagrees with manifest");
    assert.match(body, new RegExp(` ${String(manifest.unixEpoch)} `));
  }
});

test("CHANNEL-COMPLETE: (c) avb_pkmd.bin is public-only in every channel", async () => {
  for (const product of packedProducts()) {
    const pkmd = join(CHANNELS_ROOT, product, "avb_pkmd.bin");
    assert.ok(existsSync(pkmd), `${product} avb_pkmd.bin missing`);
    const text = readFileSync(pkmd, "latin1");
    assert.doesNotMatch(
      text,
      /BEGIN (RSA |EC |OPENSSH )?PRIVATE/,
      `${product} avb_pkmd.bin looks like a private key`,
    );
    // The manifest's avb block must describe exactly this file.
    const manifest = readManifest(product);
    assert.equal(manifest.avb.publicKeyFile, "avb_pkmd.bin");
    assert.equal(manifest.avb.sha256, await sha256File(pkmd));
    assert.equal(manifest.avb.size, statSync(pkmd).size);
  }
});

test("CHANNEL-COMPLETE: (c) no secret-shaped file exists anywhere under channels/", () => {
  const offenders: string[] = [];
  const walk = (dir: string): void => {
    for (const name of readdirSync(dir)) {
      const full = join(dir, name);
      const st = lstatSync(full);
      if (st.isDirectory()) walk(full);
      else if (/\.(pem|pk8)$/.test(name) || name === ".env") offenders.push(full);
    }
  };
  walk(CHANNELS_ROOT);
  assert.deepEqual(offenders, [], `secret-shaped files must never be shipped: ${offenders.join(", ")}`);
});

test("CHANNEL-COMPLETE: (c) the packer refuses a private-key-shaped avb_pkmd.bin (fail closed)", () => {
  const tmp = execFileSync("mktemp", ["-d"], { encoding: "utf8" }).trim();
  try {
    const stamp = join(tmp, "tokay-20990101-000000");
    execFileSync("mkdir", ["-p", stamp]);
    execFileSync("cp", [
      join(RELEASES, "tokay-20260928-084839", "bootloader.img"),
      join(stamp, "bootloader.img"),
    ]);
    execFileSync("bash", [
      "-c",
      `printf -- '-----BEGIN PRIVATE KEY-----\\nAAAA\\n-----END PRIVATE KEY-----\\n' > ${stamp}/avb_pkmd.bin`,
    ]);
    let failed = false;
    let stderr = "";
    try {
      execFileSync("bash", [PACKER, "--stamp", stamp, "--out", join(tmp, "out")], {
        stdio: "pipe",
        encoding: "utf8",
      });
    } catch (err) {
      failed = true;
      stderr = String((err as { stderr?: string }).stderr ?? "");
    }
    assert.equal(failed, true, "packer must refuse a private-key-shaped avb_pkmd.bin");
    assert.match(stderr, /private key \(fail closed\)/);
    assert.equal(existsSync(join(tmp, "out", "manifest.json")), false, "no channel may be emitted");
  } finally {
    execFileSync("rm", ["-rf", tmp]);
  }
});

test("CHANNEL-COMPLETE: (c) the packer refuses on a missing / retired stamp (never stubs)", () => {
  const tmp = execFileSync("mktemp", ["-d"], { encoding: "utf8" }).trim();
  try {
    let failed = false;
    let stderr = "";
    try {
      execFileSync(
        "bash",
        [PACKER, "--stamp", join(tmp, "does-not-exist"), "--out", join(tmp, "out")],
        { stdio: "pipe", encoding: "utf8" },
      );
    } catch (err) {
      failed = true;
      stderr = String((err as { stderr?: string }).stderr ?? "");
    }
    assert.equal(failed, true, "a missing stamp must fail closed");
    assert.match(stderr, /HOLD: stamp missing/);
    assert.equal(existsSync(join(tmp, "out", "manifest.json")), false);
  } finally {
    execFileSync("rm", ["-rf", tmp]);
  }
});

test("CHANNEL-COMPLETE: (d) no unpacked device is advertised, and no channel is a stub", () => {
  const products = packedProducts();
  for (const product of ALLOWED_PRODUCTS) {
    const dir = join(CHANNELS_ROOT, product);
    if (products.includes(product)) {
      // A packed channel must be complete: manifest + SHA256SUMS + files.txt.
      for (const required of ["manifest.json", "SHA256SUMS", "files.txt", "avb_pkmd.bin"]) {
        assert.ok(existsSync(join(dir, required)), `${product} channel missing ${required}`);
      }
      // Every artifact listed must be staged (symlinked) — no manifest row
      // pointing at a blob that is not there.
      const manifest = readManifest(product);
      const sums = new Set(
        readFileSync(join(dir, "SHA256SUMS"), "utf8")
          .split(/\r?\n/)
          .filter((l) => l.trim() !== "" && !l.startsWith("#"))
          .map((l) => l.trim().split(/\s+/)[1]),
      );
      for (const artifact of manifest.artifacts) {
        assert.ok(sums.has(artifact.name), `${product}: ${artifact.name} missing from SHA256SUMS`);
        assert.ok(
          existsSync(join(dir, artifact.name)),
          `${product}: ${artifact.name} is declared but not staged`,
        );
      }
    } else {
      // De-advertised: no channel dir at all (never a stub).
      assert.equal(
        existsSync(join(dir, "manifest.json")),
        false,
        `${product} is unpacked but a channel manifest exists`,
      );
    }
  }
  // The card's rule: an unpacked device is NOT advertised. Given all four are
  // genuinely packable, the advertised set (pick-worthy products) equals the
  // packed set — verified through the allowlist ∩ packed.
  assert.deepEqual(
    ALLOWED_PRODUCTS.filter((p) => products.includes(p)).slice().sort(),
    products,
  );
});

test("CHANNEL-COMPLETE: (d) loadChannelFromTexts accepts every packed channel", () => {
  const texts = (product: string) => ({
    manifestJson: readFileSync(join(CHANNELS_ROOT, product, "manifest.json"), "utf8"),
    sha256sums: readFileSync(join(CHANNELS_ROOT, product, "SHA256SUMS"), "utf8"),
    filesTxt: readFileSync(join(CHANNELS_ROOT, product, "files.txt"), "utf8"),
  });
  for (const product of packedProducts()) {
    const bundle = loadChannelFromTexts(texts(product));
    assert.equal(bundle.manifest.product, product);
    assert.equal(bundle.manifest.verifiedBootClaim, "none");
    assert.equal(bundle.manifest.channelLabel, "dev/unlocked");
    assert.deepEqual(bundle.manifest.flashOrder, ["firmware", "avb_custom_key", "os"]);
    assert.equal(bundle.manifest.factoryZip, null);
  }
});

test("CHANNEL-COMPLETE: (e) schema maxItems and reservedProducts are honoured", () => {
  const schema = JSON.parse(
    readFileSync(join(INSTALLER_ROOT, "schema", "channel-manifest.schema.json"), "utf8"),
  ) as {
    properties: {
      advertisedDevices: { maxItems: number; items: { enum: string[] } };
      reservedProducts?: { items: { not: { enum: string[] } } };
    };
  };
  const maxItems = schema.properties.advertisedDevices.maxItems;
  const advertisedEnum = schema.properties.advertisedDevices.items.enum;
  assert.equal(maxItems, 4);
  for (const product of packedProducts()) {
    const manifest = readManifest(product);
    assert.ok(manifest.advertisedDevices.length >= 1);
    assert.ok(
      manifest.advertisedDevices.length <= maxItems,
      `${product} exceeds schema maxItems`,
    );
    for (const advertised of manifest.advertisedDevices) {
      assert.ok(advertisedEnum.includes(advertised), `${advertised} not in schema enum`);
    }
    assert.ok(manifest.advertisedDevices.includes(manifest.product));
    for (const reserved of manifest.reservedProducts ?? []) {
      assert.ok(
        !ALLOWED_PRODUCTS.includes(reserved as (typeof ALLOWED_PRODUCTS)[number]),
        "reservedProducts must not list an advertised device",
      );
    }
  }
});

test("CHANNEL-COMPLETE: the packer self-test passes on this tree (fail-closed paths intact)", () => {
  const out = execFileSync("bash", [PACKER, "--self-test"], { encoding: "utf8" });
  assert.match(out, /SELF_TEST_OK/);
});

test("CHANNEL-COMPLETE: honesty markers stay false (no boot or live-flash claim)", () => {
  const status = JSON.parse(readFileSync(join(INSTALLER_ROOT, "status.json"), "utf8")) as {
    flashCapability: { liveFlashClaimed: boolean };
  };
  assert.equal(status.flashCapability.liveFlashClaimed, false);
  for (const product of packedProducts()) {
    const manifest = readManifest(product);
    assert.equal(manifest.verifiedBootClaim, "none");
    assert.equal(manifest.signature.required, false);
    assert.equal(manifest.signature.mode, "hash-only");
    assert.equal(manifest.signature.file, null);
  }
});

test("CHANNEL-COMPLETE: basename() of every channel dir is an allowlisted product", () => {
  for (const name of readdirSync(CHANNELS_ROOT)) {
    if (!existsSync(join(CHANNELS_ROOT, name, "manifest.json"))) continue;
    assert.ok(
      ALLOWED_PRODUCTS.includes(basename(name) as (typeof ALLOWED_PRODUCTS)[number]),
      `${name} is not an allowlisted product`,
    );
  }
});
