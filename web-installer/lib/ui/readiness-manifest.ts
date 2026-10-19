/**
 * GENERATED FILE — DO NOT EDIT BY HAND.
 *
 * Regenerate with: bash scripts/gen-readiness-manifest.sh
 * Deterministic from a captured report: bash scripts/gen-readiness-manifest.sh --from-tsv <file>
 *
 * Source of truth: scripts/gt-ready-devices.sh (STATUS column). That reporter is owned by
 * another card and is never edited here. This module exists so the offline browser surface
 * carries the host's tiers by derivation, not by a hand-maintained second copy.
 *
 * Honesty: BOOT_VERIFIED=false programme-wide. READY is the reporter's stamp-conferred word;
 * READY-ACK is an operator-acknowledged residual (NOT stamp-proven, NOT boot evidence);
 * BUILD-OK means boot UNVERIFIED; HOLD means host clauses pass but the stamp is
 * NOT-STAMP-VERIFIED. Nothing in this file proves that any build boots. The tier model is
 * closed: an unknown STATUS makes the generator REFUSE rather than guess.
 */

export type ReadinessStatus = "READY" | "READY-ACK" | "BUILD-OK" | "HOLD" | "PENDING";

export interface ReadinessManifestEntry {
  readonly codename: string;
  readonly model: string;
  readonly stamp: string;
  readonly status: ReadinessStatus;
  readonly reason: string;
  readonly remedy: string;
}

export interface ReadinessManifestProvenance {
  readonly sourceScript: string;
  readonly sourceScriptSha256: string;
  readonly sourceDescription: string;
  readonly sourceSha256: string;
  readonly generatedAt: string;
}

export const READINESS_MANIFEST_PROVENANCE: ReadinessManifestProvenance = {
  sourceScript: "scripts/gt-ready-devices.sh",
  sourceScriptSha256: "d9bafabfd2a94bf0bbfca5b2f2b4a0c9a88b3cdfc408a17f0ebfe6aa68fc3213",
  sourceDescription: "captured readiness report (readiness-report.tsv)",
  sourceSha256: "36c09409156cbabbae624882eda59665ec87d19d423b76f92d74a8bc66b682bc",
  generatedAt: "2026-09-30T14:42:47Z",
};

export const READINESS_MANIFEST: readonly ReadinessManifestEntry[] = [
  {
    codename: "shiba",
    model: "Pixel 8",
    stamp: "shiba-20260928-040745",
    status: "HOLD",
    reason: "host clauses PASS (stamp-bound: pointer, stamp dir, SHA256SUMS, required files, radio excision) but NOT-STAMP-VERIFIED: the only READY-conferring clause is family-provenance and stamp-INDEPENDENT, so it describes the platform family — not the bytes of shiba-20260928-040745 that would be flashed",
    remedy: "do not treat as READY for shiba-20260928-040745; add a per-stamp boot artifact (a stamp-provenance READY clause) or record an explicit operator acknowledgement that this stamp is NOT-STAMP-VERIFIED",
  },
  {
    codename: "husky",
    model: "Pixel 8 Pro",
    stamp: "husky-20260928-042016",
    status: "HOLD",
    reason: "host clauses PASS (stamp-bound: pointer, stamp dir, SHA256SUMS, required files, radio excision) but NOT-STAMP-VERIFIED: the only READY-conferring clause is family-provenance and stamp-INDEPENDENT, so it describes the platform family — not the bytes of husky-20260928-042016 that would be flashed",
    remedy: "do not treat as READY for husky-20260928-042016; add a per-stamp boot artifact (a stamp-provenance READY clause) or record an explicit operator acknowledgement that this stamp is NOT-STAMP-VERIFIED",
  },
  {
    codename: "akita",
    model: "Pixel 8a",
    stamp: "akita-20260928-083403",
    status: "HOLD",
    reason: "host clauses PASS (stamp-bound: pointer, stamp dir, SHA256SUMS, required files, radio excision) but NOT-STAMP-VERIFIED: the only READY-conferring clause is family-provenance and stamp-INDEPENDENT, so it describes the platform family — not the bytes of akita-20260928-083403 that would be flashed",
    remedy: "do not treat as READY for akita-20260928-083403; add a per-stamp boot artifact (a stamp-provenance READY clause) or record an explicit operator acknowledgement that this stamp is NOT-STAMP-VERIFIED",
  },
  {
    codename: "tokay",
    model: "Pixel 9",
    stamp: "tokay-20260725-102506",
    status: "HOLD",
    reason: "host clauses PASS (stamp-bound: pointer, stamp dir, SHA256SUMS, required files, radio excision) but NOT-STAMP-VERIFIED: the only READY-conferring clause is family-provenance and stamp-INDEPENDENT, so it describes the platform family — not the bytes of tokay-20260725-102506 that would be flashed",
    remedy: "do not treat as READY for tokay-20260725-102506; add a per-stamp boot artifact (a stamp-provenance READY clause) or record an explicit operator acknowledgement that this stamp is NOT-STAMP-VERIFIED",
  },
  {
    codename: "caiman",
    model: "Pixel 9 Pro",
    stamp: "caiman-20260928-052519",
    status: "HOLD",
    reason: "host clauses PASS (stamp-bound: pointer, stamp dir, SHA256SUMS, required files, radio excision) but NOT-STAMP-VERIFIED: the only READY-conferring clause is family-provenance and stamp-INDEPENDENT, so it describes the platform family — not the bytes of caiman-20260928-052519 that would be flashed",
    remedy: "do not treat as READY for caiman-20260928-052519; add a per-stamp boot artifact (a stamp-provenance READY clause) or record an explicit operator acknowledgement that this stamp is NOT-STAMP-VERIFIED",
  },
  {
    codename: "komodo",
    model: "Pixel 9 Pro XL",
    stamp: "komodo-20260928-052609",
    status: "HOLD",
    reason: "host clauses PASS (stamp-bound: pointer, stamp dir, SHA256SUMS, required files, radio excision) but NOT-STAMP-VERIFIED: the only READY-conferring clause is family-provenance and stamp-INDEPENDENT, so it describes the platform family — not the bytes of komodo-20260928-052609 that would be flashed",
    remedy: "do not treat as READY for komodo-20260928-052609; add a per-stamp boot artifact (a stamp-provenance READY clause) or record an explicit operator acknowledgement that this stamp is NOT-STAMP-VERIFIED",
  },
  {
    codename: "tegu",
    model: "Pixel 9a",
    stamp: "tegu-20260928-051613",
    status: "HOLD",
    reason: "host clauses PASS (stamp-bound: pointer, stamp dir, SHA256SUMS, required files, radio excision) but NOT-STAMP-VERIFIED: the only READY-conferring clause is family-provenance and stamp-INDEPENDENT, so it describes the platform family — not the bytes of tegu-20260928-051613 that would be flashed",
    remedy: "do not treat as READY for tegu-20260928-051613; add a per-stamp boot artifact (a stamp-provenance READY clause) or record an explicit operator acknowledgement that this stamp is NOT-STAMP-VERIFIED",
  },
  {
    codename: "comet",
    model: "Pixel 9 Pro Fold",
    stamp: "comet-20260928-050352",
    status: "HOLD",
    reason: "host clauses PASS (stamp-bound: pointer, stamp dir, SHA256SUMS, required files, radio excision) but NOT-STAMP-VERIFIED: the only READY-conferring clause is family-provenance and stamp-INDEPENDENT, so it describes the platform family — not the bytes of comet-20260928-050352 that would be flashed",
    remedy: "do not treat as READY for comet-20260928-050352; add a per-stamp boot artifact (a stamp-provenance READY clause) or record an explicit operator acknowledgement that this stamp is NOT-STAMP-VERIFIED",
  },
  {
    codename: "frankel",
    model: "Pixel 10",
    stamp: "frankel-20260928-055107",
    status: "BUILD-OK",
    reason: "build-ok; laguna hybrid shipped but NEVER flashed on hardware (rango hybrid reached init 0x7f00 only; fullgt is ABL-rejected)",
    remedy: "laguna hybrid is the best-available candidate (factory BP4A boot chain + GT logicals, com.android.virt.apex dropped, flags:3 vbmeta, 16384 B padded). Flash with GT_BOOT_CHAIN=hybrid and KEEP THE RESCUE BUNDLE. NOT boot-proven — expect G-logo->bootloader or 0x7f00/0xfc on failure; harvest 'fastboot oem dmesg' immediately.",
  },
  {
    codename: "blazer",
    model: "Pixel 10 Pro",
    stamp: "blazer-20260928-060401",
    status: "BUILD-OK",
    reason: "build-ok; laguna hybrid shipped but NEVER flashed on hardware (rango hybrid reached init 0x7f00 only; fullgt is ABL-rejected)",
    remedy: "laguna hybrid is the best-available candidate (factory BP4A boot chain + GT logicals, com.android.virt.apex dropped, flags:3 vbmeta, 16384 B padded). Flash with GT_BOOT_CHAIN=hybrid and KEEP THE RESCUE BUNDLE. NOT boot-proven — expect G-logo->bootloader or 0x7f00/0xfc on failure; harvest 'fastboot oem dmesg' immediately.",
  },
  {
    codename: "mustang",
    model: "Pixel 10 Pro XL",
    stamp: "mustang-20260928-061721",
    status: "BUILD-OK",
    reason: "build-ok; laguna hybrid shipped but NEVER flashed on hardware (rango hybrid reached init 0x7f00 only; fullgt is ABL-rejected)",
    remedy: "laguna hybrid is the best-available candidate (factory BP4A boot chain + GT logicals, com.android.virt.apex dropped, flags:3 vbmeta, 16384 B padded). Flash with GT_BOOT_CHAIN=hybrid and KEEP THE RESCUE BUNDLE. NOT boot-proven — expect G-logo->bootloader or 0x7f00/0xfc on failure; harvest 'fastboot oem dmesg' immediately.",
  },
  {
    codename: "stallion",
    model: "Pixel 10a",
    stamp: "stallion-20260928-052826",
    status: "HOLD",
    reason: "host clauses PASS (stamp-bound: pointer, stamp dir, SHA256SUMS, required files, radio excision) but NOT-STAMP-VERIFIED: the only READY-conferring clause is family-provenance and stamp-INDEPENDENT, so it describes the platform family — not the bytes of stallion-20260928-052826 that would be flashed",
    remedy: "do not treat as READY for stallion-20260928-052826; add a per-stamp boot artifact (a stamp-provenance READY clause) or record an explicit operator acknowledgement that this stamp is NOT-STAMP-VERIFIED",
  },
  {
    codename: "rango",
    model: "Pixel 10 Pro Fold",
    stamp: "rango-20260928-081134",
    status: "BUILD-OK",
    reason: "build-ok; laguna hybrid shipped but NEVER flashed on hardware (rango hybrid reached init 0x7f00 only; fullgt is ABL-rejected)",
    remedy: "laguna hybrid is the best-available candidate (factory BP4A boot chain + GT logicals, com.android.virt.apex dropped, flags:3 vbmeta, 16384 B padded). Flash with GT_BOOT_CHAIN=hybrid and KEEP THE RESCUE BUNDLE. NOT boot-proven — expect G-logo->bootloader or 0x7f00/0xfc on failure; harvest 'fastboot oem dmesg' immediately.",
  },
];
