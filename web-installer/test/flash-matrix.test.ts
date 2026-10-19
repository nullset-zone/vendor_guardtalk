/**
 * T-WEBINSTALL-FLASHALL-INVENTORY — generated device × channel × phase matrix.
 *
 * These tests LOCK the invariants of the generated artifact workspace
 * `docs/flash-matrix.json`. They do NOT re-implement the generator; they assert
 * that the generator's output obeys the card's acceptance criteria:
 *
 *   (a) the matrix is generated, not hand-written (the docs are reproducible
 *       from the tree with a checkable drift exit code);
 *   (b) every image in files.txt/SHA256SUMS maps to a declared flash phase;
 *   (c) the advertised/packed divergence is enumerated per device with the
 *       exact source line that advertises it;
 *   (d) the artifact records its generation command + the revision derived from;
 *   (e) the numbers reconcile with status.json / src/types.ts by construction.
 */
import assert from "node:assert/strict";
import { test } from "node:test";
import { existsSync, readFileSync } from "node:fs";
import { join } from "node:path";
import {
  ARTIFACT_PHASES,
  FLASH_ORDER,
  INSTALLER_ROOT,
  buildMatrix,
  phaseForArtifact,
  readAllowedProducts,
  readStatusTargets,
  type FlashMatrix,
} from "../scripts/gen-flash-matrix.mjs";

const MATRIX_PATH = join(INSTALLER_ROOT, "docs", "flash-matrix.json");
const MATRIX_MD_PATH = join(INSTALLER_ROOT, "docs", "flash-matrix.md");

function committedMatrix(): FlashMatrix {
  assert.ok(existsSync(MATRIX_PATH), `missing generated artifact: ${MATRIX_PATH}`);
  return JSON.parse(readFileSync(MATRIX_PATH, "utf8")) as FlashMatrix;
}

test("INVENTORY: docs/flash-matrix.json is checked in and is a generated artifact", () => {
  const matrix = committedMatrix();
  assert.equal(matrix.schemaVersion, 1);
  assert.match(matrix.$comment, /GENERATED/);
  assert.match(matrix.$comment, /DO NOT EDIT BY HAND/);
  // (d) the artifact records its own generation command + revision.
  assert.equal(matrix.generationCommand, "node scripts/gen-flash-matrix.mjs");
  assert.equal(typeof matrix.revision, "string");
  assert.notEqual(matrix.revision.trim(), "");
  assert.match(matrix.generatedAt, /^\d{4}-\d{2}-\d{2}T/);
  assert.ok(existsSync(MATRIX_MD_PATH), "missing Markdown rendering");
});

test("INVENTORY: the committed matrix is reproducible from the live tree (derived, not hand-written)", () => {
  const committed = committedMatrix();
  const derived = buildMatrix({
    generatedAt: committed.generatedAt,
    generationCommand: "node scripts/gen-flash-matrix.mjs",
    revision: committed.revision,
  });
  // Byte-for-byte equality of the DERIVED data: the only injectable bytes are
  // generatedAt + revision, which we feed back as the committed values.
  assert.deepEqual(derived.devices, committed.devices);
  assert.deepEqual(derived.divergence, committed.divergence);
  assert.deepEqual(derived.counts, committed.counts);
  assert.deepEqual(derived.sources, committed.sources);
});

test("INVENTORY: every packed artifact maps to a declared flash phase and flash order step", () => {
  const matrix = committedMatrix();
  const packed = matrix.devices.filter((d) => d.packed);
  assert.ok(packed.length >= 1, "expected at least one packed device");
  for (const device of packed) {
    for (const channel of device.channels) {
      assert.ok(channel.artifacts.length >= 1);
      for (const artifact of channel.artifacts) {
        // (b) every image maps to a phase — an UNMAPPED artifact fails.
        assert.notEqual(
          artifact.declaredPhase,
          null,
          `${device.product}/${artifact.name} has no declared phase`,
        );
        assert.ok(
          (ARTIFACT_PHASES as readonly string[]).includes(artifact.declaredPhase as string),
          `${device.product}/${artifact.name} has no declared phase`,
        );
        assert.equal(artifact.declaredPhase, artifact.filesTxtPhase);
        assert.equal(artifact.phaseMatches, true);
        assert.equal(artifact.inManifest, true);
        assert.ok(artifact.flashStep >= 0 && artifact.flashStep <= 9);
        assert.ok((FLASH_ORDER as readonly string[]).includes(artifact.flashOrderPhase));
      }
      // No artifact may be present in the manifest but missing a phase row.
      assert.deepEqual(channel.unmappedArtifacts, []);
    }
  }
});

test("INVENTORY: phaseForArtifact mirrors the packer's phase_for mapping", () => {
  assert.equal(phaseForArtifact("bootloader.img"), "firmware");
  assert.equal(phaseForArtifact("radio.img"), "firmware");
  assert.equal(phaseForArtifact("avb_pkmd.bin"), "avb");
  assert.equal(phaseForArtifact("boot.img"), "os");
  assert.equal(phaseForArtifact("system.img"), "os");
  // A non-image is not published by the packer and must not be mapped.
  assert.equal(phaseForArtifact("README-FLASH-DESKTOP.md"), null);
  assert.equal(phaseForArtifact("init.insmod.tokay.cfg"), null);
});

test("INVENTORY: advertised-vs-packed divergence names the exact advertising source line", () => {
  const matrix = committedMatrix();
  const allow = readAllowedProducts();
  const status = readStatusTargets();

  // (e) numbers reconcile with the live sources by construction.
  assert.equal(matrix.counts.allowlist, allow.products.length);
  assert.equal(matrix.counts.statusTargets, status.targets.length);
  assert.equal(matrix.counts.statusExperimentalTargets, status.experimentalTargets.length);
  assert.deepEqual(matrix.sources.allowlist.products, allow.products);
  assert.equal(matrix.sources.allowlist.line, allow.sourceLine);

  // (c) each divergence row cites at least one exact source.
  for (const row of matrix.divergence) {
    assert.ok(row.advertisedBy.length >= 1, `${row.product} has no advertising source`);
    for (const source of row.advertisedBy) {
      assert.match(source, /(src\/types\.ts:\d+|status\.json)/);
    }
  }

  const byProduct = new Map(matrix.divergence.map((r) => [r.product, r]));
  // komodo: advertised in ALLOWED_PRODUCTS but ABSENT from the product facts.
  // The INVENTORY card's finding was komodo advertised with no packed channel;
  // CHANNEL-COMPLETE packs it from its real September stamp, so the residual
  // that remains is the product-facts gap, not an unpacked channel.
  const komodo = byProduct.get("komodo");
  assert.ok(komodo, "komodo must appear in the divergence ledger");
  assert.equal(komodo.absentFromProductFacts, true);
  assert.equal(komodo.inTargets, false);
  assert.equal(komodo.inExperimental, false);
  assert.equal(komodo.packed, true);
  assert.equal(komodo.verdict, "PACKED-CURRENT");
  // It is still advertised ONLY by the allowlist — the exact source is named.
  assert.deepEqual(komodo.advertisedBy, ["src/types.ts:3 (ALLOWED_PRODUCTS)"]);
  // rango: advertised and now genuinely packed from its current stamp.
  const rango = byProduct.get("rango");
  assert.ok(rango, "rango must appear in the divergence ledger");
  assert.equal(rango.packed, true);
  assert.equal(rango.verdict, "PACKED-CURRENT");
  assert.equal(rango.inTargets, true);
});

test("INVENTORY: the shipped channels are all current (no July-stale pack survives the repack)", () => {
  const matrix = committedMatrix();
  // The INVENTORY card's finding was that both packed channels were July-stale
  // (the DEC-ARCH-025 failure mode on the flash path). CHANNEL-COMPLETE repacks
  // them from the current stamps, so the invariant this test now locks is:
  // every packed channel's sourceStamp EQUALS its advertised current stamp.
  for (const device of matrix.devices) {
    if (!device.packed) continue;
    assert.ok(device.currentStamp, `${device.product} is packed but has no current stamp`);
    for (const channel of device.channels) {
      assert.equal(
        channel.sourceStamp,
        device.currentStamp,
        `${device.product} channel sourceStamp is stale relative to its current stamp`,
      );
      assert.equal(channel.sourceStampIsCurrent, true);
      assert.doesNotMatch(channel.sourceStamp, /-202607\d{2}-/, "a July stamp survived the repack");
    }
  }
  // And the summary must agree: nothing advertised is left unpacked, nothing stale.
  assert.deepEqual(matrix.summary.staleChannels, []);
  assert.deepEqual(matrix.summary.advertisedNotPacked, []);
});

test("INVENTORY: the matrix never invents a channel", () => {
  const matrix = committedMatrix();
  for (const device of matrix.devices) {
    if (device.packed) {
      assert.ok(
        existsSync(join(INSTALLER_ROOT, "channels", device.product, "manifest.json")),
        `${device.product} is marked packed but has no manifest on disk`,
      );
    } else {
      assert.equal(device.channels.length, 0);
      assert.equal(
        existsSync(join(INSTALLER_ROOT, "channels", device.product, "manifest.json")),
        false,
        `${device.product} is marked unpacked but a channel exists on disk`,
      );
    }
  }
});

test("INVENTORY: honesty markers stay false (no boot or live-flash claim)", () => {
  const matrix = committedMatrix();
  assert.equal(matrix.honesty.bootVerified, false);
  assert.equal(matrix.honesty.liveFlashClaimed, false);
});
