/**
 * Evidence harness for F-EXCISE-WEBINSTALL-READINESS-GUARD (not a test).
 * Run: npx tsx test/readiness-evidence.ts
 *
 * Prints, for each acceptance path, the decision the shipped policy makes and
 * the markup the shipped renderer emits — plus the claim-linter negative
 * control. No DOM, no hardware, no network.
 */
import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { fileURLToPath } from "node:url";
import { lintFiles } from "../lib/claims/lint-claims.js";
import {
  OFFERABLE_TIERS,
  READINESS_PROVENANCE,
  TIER_POLICY,
  acknowledgementMatches,
  canCommitSelection,
  canCommitTier,
  isOfferable,
  readinessChipWord,
  readinessFor,
  requiresAcknowledgement,
  tierPolicy,
  tierRequiresAcknowledgement,
} from "../lib/ui/readiness.js";
import { renderReadinessGate, renderStep0 } from "../routes/install/early-steps.js";

const line = (label: string): void => console.log(`\n===== ${label} =====`);

line("Manifest provenance (derived, not hand-written)");
console.log("source script     :", READINESS_PROVENANCE.sourceScript);
console.log("source sha256     :", READINESS_PROVENANCE.sourceScriptSha256);
console.log("report sha256     :", READINESS_PROVENANCE.sourceSha256);
console.log("source            :", READINESS_PROVENANCE.sourceDescription);
console.log("generated at (UTC):", READINESS_PROVENANCE.generatedAt);

line("Host-reported tiers for the four advertised devices");
for (const product of ["tokay", "akita", "komodo", "rango"] as const) {
  const view = readinessFor(product);
  console.log(
    `${product.padEnd(7)} tier=${view.tier.padEnd(9)} offerable=${String(view.offerable).padEnd(5)} requiresAck=${String(view.requiresAcknowledgement).padEnd(5)} stamp=${view.stamp}`,
  );
}

line("Path A — READY (policy; no READY device in the host report today)");
console.log("canCommitTier(READY, x, undefined) :", canCommitTier("READY", "tokay", undefined));
console.log("renderStep0('tokay') gate present  :", /data-readiness-gate="/.test(renderStep0("tokay")));
console.log("renderStep0('tokay') selection     :", /option value="tokay"[^>]* selected/.exec(renderStep0("tokay"))?.[0] ?? "(none)");

line("Path B — BUILD-OK blocked (rango, no acknowledgement)");
console.log("tier                              :", readinessFor("rango").tier);
console.log("requiresAcknowledgement           :", requiresAcknowledgement("rango"));
console.log("canCommitSelection(rango, undef.)  :", canCommitSelection("rango", undefined));
console.log("typed 'y' matches                  :", acknowledgementMatches("rango", "y"));
console.log("typed 'rango' matches              :", acknowledgementMatches("rango", "rango"));
const blocked = renderStep0("tokay", {
  product: "rango",
  deviceName: readinessFor("rango").model,
  tier: "BUILD-OK",
  reason: readinessFor("rango").reason,
  remedy: readinessFor("rango").remedy,
});
console.log("gate present                       :", /data-readiness-gate="BUILD-OK"/.test(blocked));
console.log("still on prior selection           :", /option value="tokay"[^>]* selected/.test(blocked));
console.log("gate heading                       :", /BUILD-OK — this build is not boot-verified\./.test(blocked));
console.log("boot flag rendered                 :", /BOOT_VERIFIED=false/.test(blocked));

line("Path B — BUILD-OK acknowledged (codename typed)");
console.log("canCommitSelection(rango, rango)   :", canCommitSelection("rango", "rango"));
const acknowledged = renderStep0("rango");
console.log("gate present                       :", /data-readiness-gate="/.test(acknowledged));
console.log("selection                          :", /option value="rango"[^>]* selected/.exec(acknowledged)?.[0] ?? "(none)");

line("Path C — HOLD has no acknowledgement path");
const holdProduct = (["tokay", "akita", "komodo"] as const).find(
  (p) => readinessFor(p).tier === "HOLD",
);
if (holdProduct === undefined) {
  console.log("(no HOLD device in the host report — nothing to exercise)");
} else {
  console.log("device                            :", holdProduct);
  console.log("canCommitTier(HOLD, x, undefined) :", canCommitTier("HOLD", holdProduct, undefined));
  console.log("canCommitTier(HOLD, x, 'codename'):", canCommitTier("HOLD", holdProduct, holdProduct));
  const holdGate = renderReadinessGate({
    product: holdProduct,
    deviceName: readinessFor(holdProduct).model,
    tier: readinessFor(holdProduct).tier,
    reason: readinessFor(holdProduct).reason,
    remedy: readinessFor(holdProduct).remedy,
  });
  console.log("gate present (not acknowledgeable):", /data-readiness-gate="HOLD"/.test(holdGate));
  console.log("acknowledge button absent         :", !/acknowledge-build-ok/.test(holdGate));
}

line("Tier policy map (fail-closed authority — T-EXCISE-WEBINSTALL-ACK-ABSORB)");
for (const tier of Object.keys(TIER_POLICY)) {
  const policy = tierPolicy(tier);
  console.log(
    `${tier.padEnd(10)} offerable=${String(policy?.offerable).padEnd(5)} requiresAck=${String(policy?.requiresAcknowledgement).padEnd(5)} agrees=${String(
      isOfferable(tier) === policy?.offerable && tierRequiresAcknowledgement(tier) === policy?.requiresAcknowledgement,
    )} word="${readinessChipWord(tier)}"`,
  );
}
console.log("OFFERABLE_TIERS                   :", OFFERABLE_TIERS.join(", "));

line("Adversarial — an unknown/added tier token is REFUSED (the QA fail-open)");
const INTERLOPERS = ["READY-NEW", "SUPER-READY", "READY_ACK", "ready-ack", "FLASHY", "", "__proto__", "constructor", "toString", "hasOwnProperty"];
for (const token of INTERLOPERS) {
  console.log(
    `${JSON.stringify(token).padEnd(18)} policy=${String(tierPolicy(token)).padEnd(9)} offerable=${String(isOfferable(token)).padEnd(5)} canCommitTier(ack=codename)=${canCommitTier(token, "rango", "rango")}`,
  );
}

line("Path D — READY-ACK (distinct, non-READY, acknowledgement-gated)");
console.log("chip word                         :", readinessChipWord("READY-ACK"));
console.log("distinct from READY               :", readinessChipWord("READY-ACK") !== readinessChipWord("READY"));
console.log("canCommitTier(READY-ACK, no ack)  :", canCommitTier("READY-ACK", "rango", undefined));
console.log("canCommitTier(READY-ACK, wrong)   :", canCommitTier("READY-ACK", "rango", "tokay"));
console.log("canCommitTier(READY-ACK, codename):", canCommitTier("READY-ACK", "rango", "rango"));
const readyAckGate = renderReadinessGate({
  product: "tokay",
  deviceName: "Pixel 9",
  tier: "READY-ACK",
  reason: "host clauses pass, readiness NOT stamp-conferred; operator acknowledgement on record (synthetic view)",
  remedy: "flash only under the recorded acknowledgement",
});
console.log("data-readiness-gate=READY-ACK     :", /data-readiness-gate="READY-ACK"/.test(readyAckGate));
console.log("acknowledgement input present     :", /data-role="readiness-ack"/.test(readyAckGate));
console.log("renders plain READY tier          :", /Tier<\/dt><dd>READY<\/dd>/.test(readyAckGate));
console.log("BOOT_VERIFIED=false               :", /BOOT_VERIFIED=false/.test(readyAckGate));

line("Drift decoupling — recorded fingerprint vs live reporter");
const sideCar = fileURLToPath(new URL("./fixtures/readiness/readiness-report.reporter.sha256", import.meta.url));
const liveReporter = fileURLToPath(new URL("../../../../scripts/gt-ready-devices.sh", import.meta.url));
const recordedSha = (readFileSync(sideCar, "utf8").trim().split(/\s+/)[0] ?? "").trim();
const liveSha = createHash("sha256").update(readFileSync(liveReporter)).digest("hex");
console.log("recorded (shipped provenance)      :", recordedSha);
console.log("live reporter sha256               :", liveSha);
console.log("live differs from recorded         :", liveSha !== recordedSha);
console.log("shipped provenance == recorded     :", READINESS_PROVENANCE.sourceScriptSha256 === recordedSha);

line("Claim-linter negative control");
const bad = fileURLToPath(new URL("./fixtures/claims/readiness-overclaim.txt", import.meta.url));
const honest = fileURLToPath(new URL("./fixtures/claims/readiness-honest.txt", import.meta.url));
console.log("--- bad fixture ---");
console.log(readFileSync(bad, "utf8").trimEnd());
console.log("hits:");
for (const hit of lintFiles([bad])) {
  console.log(`  ${hit.file.split("/").pop()}:${hit.line} [${hit.rule}] ${hit.excerpt}`);
}
console.log("--- honest fixture ---");
console.log("hits:", lintFiles([honest]).length);
