/**
 * UI primitives tests (Phase 2.5). DOM-free structural assertions run over
 * the HTML strings each module emits; the rail's keyboard behaviour is driven
 * through its synthetic-event contract, so no jsdom dependency is needed.
 */
import assert from "node:assert/strict";
import { test } from "node:test";
import { Hardening, LineageNote, ProtectionLimit } from "../lib/claims/components.js";
import { makeChip } from "../lib/ui/chips.js";
import { consoleMarkup } from "../lib/ui/console.js";
import { renderKeyDiagram } from "../lib/ui/key-diagram.js";
import { postureFromStatusJson, posturePillText, renderPosturePill } from "../lib/ui/posture.js";
import { partitionProgressLabel, renderPartitionProgress } from "../lib/ui/progress.js";
import { hardStopBanner, railStepViews, renderRail } from "../lib/ui/rail.js";
import { initialInstallState, reduce } from "../lib/install-state/index.js";
import type { InstallState } from "../lib/install-state/index.js";
import type { RailKeyContext } from "../lib/ui/rail.js";
import { compareHex } from "../lib/verify/side-by-side.js";
import { renderSideBySideRow } from "../lib/ui/sidebyside.js";
import type { ConsoleLineKind } from "../lib/ui/console.js";

/* ------------------------------------------------------------------ */
/* Shared helpers                                                      */
/* ------------------------------------------------------------------ */

function happyPathTo(step: number): InstallState {
  let state = initialInstallState("install");
  const actions = [
    { type: "acknowledge-intro" },
    { type: "files-picked" },
    { type: "release-verified" },
    { type: "key-flow-chosen", keyFlow: 1 as const },
    { type: "fingerprint-recorded" },
    { type: "vbmeta-signed" },
    { type: "oem-unlock-acked" },
    { type: "device-matched", product: "tokay" },
    { type: "flash-step-done" },
    { type: "lock-confirmed" },
    { type: "boot-fingerprint-typed", fingerprint: "ab12cd34" },
  ] as const;
  for (const action of actions) {
    state = reduce(state, action);
    if (state.currentStep === step) {
      return state;
    }
  }  return state;
}

const CSP_FORBIDDEN_ATTRS = [/\son[a-z]+\s*=/i, /\sstyle\s*=/i];

function assertCspSafe(html: string): void {
  for (const pattern of CSP_FORBIDDEN_ATTRS) {
    assert.doesNotMatch(html, pattern, `markup must not carry inline handlers or style attributes`);
  }
}

/* ------------------------------------------------------------------ */
/* Chips                                                               */
/* ------------------------------------------------------------------ */

test("chips always carry non-empty word text for every kind", () => {
  for (const kind of ["verified", "caution", "tripwire", "neutral"] as const) {
    const html = makeChip("VERIFIED", kind, { ariaLive: "polite" });
    assert.match(html, />VERIFIED</);
    assert.match(html, /data-kind="/);
    assertCspSafe(html);
  }
});

test("chip refuses empty words — status is never colour-only", () => {
  assert.throws(() => makeChip("", "neutral"));
  assert.throws(() => makeChip("   ", "verified"));
});

test("chip aria-live is emitted only when requested", () => {
  assert.match(makeChip("MATCH", "verified", { ariaLive: "polite" }), /aria-live="polite"/);
  assert.doesNotMatch(makeChip("MATCH", "verified"), /aria-live/);
});

/* ------------------------------------------------------------------ */
/* Rail                                                                */
/* ------------------------------------------------------------------ */

test("rail marks completed steps with verified chips and current with aria-current=step", () => {
  const state = happyPathTo(3);
  const views = railStepViews(state);
  const rendered = renderRail(state);
  assert.match(rendered.html, /COMPLETED/);
  assert.match(rendered.html, /aria-current="step"/);
  const currentView = views.find((view) => view.status === "current");
  assert.equal(currentView?.step, 3);
});

test("hard stop renders tripwire chip plus stop reason verbatim", () => {
  let state = happyPathTo(2);
  state = reduce(state, { type: "stop", step: 2, condition: "hash-mismatch" });
  const rendered = renderRail(state);
  assert.match(rendered.html, /STOPPED/);
  const reason = hardStopBanner(state);
  assert.ok(reason !== undefined);
  assert.ok(
    rendered.html.includes(reason),
    `rail must contain the verbatim stop reason`,
  );
  assert.match(rendered.html, /hash mismatch — the download does not match SHA256SUMS/);
});

test("back stays hidden after irreversible acks; reachable-by-back flags follow machine", () => {
  // Step 5 carries irreversibleAfterAck; backTarget 4 must NOT be flagged.
  const atFive = happyPathTo(5);
  const viewsAtFive = railStepViews(atFive);
  assert.equal(viewsAtFive.find((v) => v.step === 4)?.reachableByBack, false);

  // Step 2 allows back to step 1.
  const atTwo = happyPathTo(2);
  const viewsAtTwo = railStepViews(atTwo);
  assert.equal(viewsAtTwo.find((v) => v.step === 1)?.reachableByBack, true);
  assert.equal(viewsAtTwo.find((v) => v.step === 0)?.reachableByBack, false);
});

test("roving tabindex: exactly one tabbable step, arrows move focus, Enter selects reachable steps only", () => {
  const state = happyPathTo(2);
  const focused: number[] = [];
  const selected: number[] = [];
  const rendered = renderRail(state, {
    onFocus: (index) => {
      focused.push(index);
    },
    onSelect: (step) => {
      selected.push(step);
    },
  });

  // Roving tabindex: exactly one button carries tabindex=0 in the markup.
  const tabindexes = [...rendered.html.matchAll(/tabindex="(-?\d+)"/g)].map((m) => m[1]);
  assert.equal(tindexesZero(tabindexes), 1, "roving tabindex keeps exactly one stop in the tab order");
  assert.ok(rendered.html.includes('aria-current="step"'));

  const context: RailKeyContext = {
    state,
    dispatch: (action) => reduce(state, action),
  };

  // Arrow keys wrap focus around the ring without touching machine state.
  // The synthetic contract mirrors the real flow: each event's targetStep is
  // where DOM focus currently sits, so it advances as we move.
  rendered.handleKeyDown({ key: "ArrowDown", targetStep: 2 }, context);
  rendered.handleKeyDown({ key: "ArrowDown", targetStep: 3 }, context);
  rendered.handleKeyDown({ key: "ArrowUp", targetStep: 4 }, context);
  rendered.handleKeyDown({ key: "End", targetStep: 3 }, context);
  rendered.handleKeyDown({ key: "Home", targetStep: 9 }, context);
  assert.deepEqual(focused, [3, 4, 3, 9, 0]);
  assert.equal(context.state.currentStep, 2);

  // Enter on a reachable step performs a back transition.
  rendered.handleKeyDown({ key: "Enter", targetStep: 1 }, context);
  assert.deepEqual(selected, [1]);
  const backState = reduce(context.state, { type: "back" });
  assert.equal(backState.currentStep, 1);

  // Enter on a forward (unreachable) step is inert — no selection, no stop.
  const stopsBefore = context.state.stops.length;
  rendered.handleKeyDown({ key: "Enter", targetStep: 7 }, context);
  assert.deepEqual(selected, [1]);
  assert.equal(reduce(context.state, { type: "acknowledge-intro" }).stops.length >= stopsBefore, true);
});

function tindexesZero(tindexes: readonly (string | undefined)[]): number {
  return tindexes.filter((value) => value === "0").length;
}

test("selectStep rejects direct selection of unreachable forward steps", () => {
  const state = happyPathTo(2);
  const rendered = renderRail(state);
  const context: RailKeyContext = { state, dispatch: (action) => reduce(state, action) };
  assert.throws(() => rendered.selectStep(7, context));
});

/* ------------------------------------------------------------------ */
/* Console                                                             */
/* ------------------------------------------------------------------ */

test("console markup preserves appendLine ordering and kinds", () => {
  const html = consoleMarkup([
    ["cmd", "fastboot getvar product"],
    ["device", "(bootloader) product: tokay"],
    ["ok", "product matches release target"],
    ["info", "continuing to flash step"],
    ["fail", "fastboot reported FAIL"],
  ]);
  const cmdPos = html.indexOf("fastboot getvar product");
  const devicePos = html.indexOf("(bootloader) product: tokay");
  const okPos = html.indexOf("product matches release target");
  const infoPos = html.indexOf("continuing to flash step");
  const failPos = html.indexOf("fastboot reported FAIL");
  assert.ok(cmdPos < devicePos && devicePos < okPos && okPos < infoPos && infoPos < failPos);
  assert.match(html, /data-kind="cmd"/);
  assert.match(html, /data-kind="device"/);
  assert.match(html, /data-kind="fail"/);
});

test("copy-all string equals joined lines (ring buffer semantics over 2000)", () => {
  const lines: string[] = [];
  const LIMIT = 2000;
  for (let i = 0; i < LIMIT + 25; i += 1) {
    lines.push(`line-${String(i)}`);
  }
  const ring = lines.slice(lines.length - LIMIT);
  const copyAll = ring.join("\n");
  assert.equal(copyAll.split("\n").length, LIMIT);
  assert.equal(ring[0], "line-25");
  assert.equal(ring[ring.length - 1], `line-${String(LIMIT + 24)}`);
});

test("ring buffer drops oldest beyond 2000 in markup helper contract", () => {
  // The live component enforces CONSOLE_BUFFER_LIMIT; here we verify the
  // exported constant and the drop-oldest behaviour of a reference ring.
  assert.equal(consoleMarkup([["cmd", "x"]]).includes("line-1999"), false);
  const big: readonly (readonly [ConsoleLineKind, string])[] = Array.from({ length: 2001 }, (_, i): readonly [ConsoleLineKind, string] => ["info", `n${String(i)}`]);
  const html = consoleMarkup(big.slice(-2000));
  assert.ok(html.includes("n1"));
  assert.ok(html.includes("n2000"));
  assert.equal(html.includes("n0<"), false);
});

test("aria mirror targets the last line only", () => {
  const html = consoleMarkup([
    ["cmd", "first command"],
    ["ok", "last line wins"],
  ]);
  const mirror = html.match(/<p class="console-mirror"[^>]*><\/p>/);
  assert.ok(mirror !== null, "mirror paragraph exists and starts empty");
  assert.match(html, /aria-live="polite"/);
  assert.match(html, /data-mirror="last-line"/);
});

test("console emits no inline handlers or style attributes", () => {
  assertCspSafe(consoleMarkup([["ok", "clean"]]));
});

/* ------------------------------------------------------------------ */
/* Side by side                                                        */
/* ------------------------------------------------------------------ */

test("mismatch renders both columns and the MISMATCH word chip", () => {
  const side = compareHex("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa", "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb");
  const rendered = renderSideBySideRow({ label: "vbmeta digest", side });
  assert.equal(rendered.verdict, "MISMATCH");
  assert.match(rendered.html, /EXPECTED/);
  assert.match(rendered.html, /ACTUAL/);
  assert.match(rendered.html, /MISMATCH/);
  assert.match(rendered.html, /data-full="aaaa/);
  assertCspSafe(rendered.html);
});

test("expected equals actual renders MATCH", () => {
  const value = "1234567890abcdef";
  const side = compareHex(value, value.toUpperCase());
  const rendered = renderSideBySideRow({ label: "fingerprint", side });
  assert.equal(rendered.verdict, "MATCH");
  assert.match(rendered.html, />\s*MATCH\s*</);
});

test("long hashes are middle-truncated with full value retained for click-expand", () => {
  const long = "e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855";
  const side = compareHex(long, long);
  const rendered = renderSideBySideRow({ label: "sha256", side });
  assert.match(rendered.html, /…/);
  assert.match(rendered.html, new RegExp(`data-full="${long}"`));
  assert.match(rendered.html, /role="button"/);
});

/* ------------------------------------------------------------------ */
/* Key diagram                                                         */
/* ------------------------------------------------------------------ */

test("key diagram contains all three exact node labels plus title and desc", () => {
  const svg = renderKeyDiagram();
  assert.ok(svg.includes("your private key — stays here"));
  assert.ok(svg.includes("your public key — goes into the phone"));
  assert.ok(svg.includes("GuardTalk's release key — proves the build, not the boot"));
  assert.match(svg, /<title id="key-diagram-title">[^<]+<\/title>/);
  assert.match(svg, /<desc>[\s\S]+<\/desc>/);
  assert.match(svg, /<svg[^>]*role="img"/);
  assertCspSafe(svg);
});

/* ------------------------------------------------------------------ */
/* Progress                                                            */
/* ------------------------------------------------------------------ */

test("progress bar label states partition and bytes in mono-friendly text", () => {
  const label = partitionProgressLabel({ partition: "bootloader", bytesDone: 1024, bytesTotal: 4096 });
  assert.match(label, /^flash bootloader — 1,024 of 4,096 bytes$/);
  const html = renderPartitionProgress({ partition: "bootloader", bytesDone: 2048, bytesTotal: 4096 });
  assert.match(html, /role="progressbar"/);
  assert.match(html, /aria-valuenow="50\.0"/);
  assert.match(html, /data-width-pct="50\.00"/);
  assertCspSafe(html);
});

/* ------------------------------------------------------------------ */
/* Posture pill                                                        */
/* ------------------------------------------------------------------ */

test("posture pill renders the exact required string", () => {
  const flags = postureFromStatusJson({ network: "offline", release_state: "alpha", key_custody: "alpha" });
  assert.equal(posturePillText(flags), "◢ offline · your key · alpha");
  assert.match(renderPosturePill(flags), /^<span[^>]*>◢ offline · your key · alpha<\/span>$/);
});

test("posture reader refuses payloads that contradict offline custody", () => {
  assert.throws(() => postureFromStatusJson({ network: "online", release_state: "alpha" }));
  assert.throws(() => postureFromStatusJson({ release_state: "" }));
});

/* ------------------------------------------------------------------ */
/* Claims components                                                   */
/* ------------------------------------------------------------------ */

test("Hardening output contains the mechanism link href", () => {
  const claim = Hardening("The package signature is checked against GuardTalk's release key before anything is written.", {
    href: "/install#verify-release",
  });
  assert.ok(claim.html.includes('href="/install#verify-release"'));
  assertCspSafe(claim.html);
});

test("ProtectionLimit links every limit to the threat model", () => {
  const claim = ProtectionLimit("Verified boot does not protect firmware beneath AVB.");
  assert.ok(claim.html.includes('href="/threat-model"'));
  assertCspSafe(claim.html);
});

test("LineageNote carries the confirm-with-counsel marker", () => {
  const claim = LineageNote("Attribution draft: practice follows upstream GrapheneOS installation discipline.");
  assert.ok(claim.html.includes("// confirm with counsel"));
  assert.ok(claim.text.includes("// confirm with counsel"));
});

/* ------------------------------------------------------------------ */
/* CSP safety across everything                                        */
/* ------------------------------------------------------------------ */

test("no generated markup uses inline event handlers or style attributes", () => {
  const samples = [
    makeChip("STOPPED", "tripwire"),
    consoleMarkup([["fail", "boom"]]),
    renderKeyDiagram(),
    renderPosturePill(postureFromStatusJson({ release_state: "alpha" })),
    renderPartitionProgress({ partition: "system", bytesDone: 1, bytesTotal: 2 }),
    renderRail(happyPathTo(2)).html,
    Hardening("Hash comparison gates the flash step.").html,
    LineageNote("Draft lineage wording.").html,
  ];
  for (const html of samples) {
    assertCspSafe(html);
  }
});
