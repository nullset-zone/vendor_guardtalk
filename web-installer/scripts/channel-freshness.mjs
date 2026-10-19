#!/usr/bin/env node
/**
 * channel-freshness.mjs — the channel freshness invariant, as pure functions.
 *
 * T-WEBINSTALL-FLASHALL-FRESHNESS. A shipped channel is a POINTER into a
 * desktop-flash stamp: its manifest records `releaseId` / `unixEpoch` /
 * `sourceStamp`, and its `SHA256SUMS` pins the bytes of that stamp. If the
 * stamp the channel was packed from is no longer the stamp the product points
 * at, the channel is STALE — flashing it would write a superseded build (the
 * DEC-ARCH-025 failure mode, here on the flash path). The July→September drift
 * on `tokay` / `akita` is exactly this class.
 *
 * This is the ONE implementation of the invariant. The readiness gate
 * (`scripts/readiness-gate.mjs`) imports it, so the gate's `channel-freshness`
 * clause and the freshness tests cannot diverge. Pure ESM → usable from both
 * plain `node` (the gate) and `tsx` (the tests).
 *
 * FRESHNESS RULES (all must hold; each names its own failure):
 *   1. `sourceStamp` is a well-formed `<product>-YYYYMMDD-HHMMSS` stamp name
 *      AND names the channel's own product.
 *   2. the stamp the channel names EXISTS on disk (a stamp dir, not a pointer).
 *   3. `sourceStamp` === the product's advertised `currentStamp` (the
 *      `<product>-latest` pointer target). A mismatch is stale.
 *   4. `releaseId` === the `YYYYMMDD-HHMMSS` token of `sourceStamp`.
 *   5. `unixEpoch` === the UTC epoch of that timestamp.
 *
 * FAIL CLOSED: any missing input is a failure, never treated as fresh.
 *
 * HONESTY: freshness says "this channel was packed from the stamp you point
 * at", never "this build boots". `BOOT_VERIFIED=false`.
 */

const STAMP_RE = /^([a-z0-9]+)-([0-9]{8})-([0-9]{6})$/;

/** Parse a stamp name into its product + UTC epoch. `null` when malformed. */
export function parseStamp(stamp) {
  const m = STAMP_RE.exec(String(stamp));
  if (m === null) return null;
  const [, product, date, time] = m;
  if (product === undefined || date === undefined || time === undefined) return null;
  const y = Number(date.slice(0, 4));
  const mo = Number(date.slice(4, 6));
  const d = Number(date.slice(6, 8));
  const h = Number(time.slice(0, 2));
  const mi = Number(time.slice(2, 4));
  const s = Number(time.slice(4, 6));
  if (mo < 1 || mo > 12 || d < 1 || d > 31 || h > 23 || mi > 59 || s > 59) return null;
  return {
    product,
    releaseId: `${date}-${time}`,
    unixEpoch: Date.UTC(y, mo - 1, d, h, mi, s) / 1000,
  };
}

/**
 * Evaluate the freshness invariant for one channel. Pure.
 *
 * @param {string} product
 * @param {{sourceStamp:string, releaseId:string, unixEpoch:number, currentStamp:string|null, stampsOnDisk:readonly string[]}} input
 * @returns {{fresh:boolean, product:string, clauses:{id:string,ok:boolean,detail:string}[]}}
 */
export function checkChannelFreshness(product, input) {
  const clauses = [];

  // Rule 1: the stamp name is well-formed.
  const parsed = parseStamp(input.sourceStamp);
  clauses.push({
    id: "source-stamp-well-formed",
    ok: parsed !== null,
    detail:
      parsed !== null
        ? `${input.sourceStamp} parses as ${parsed.product}/${parsed.releaseId}`
        : `sourceStamp is not a <product>-YYYYMMDD-HHMMSS stamp: ${JSON.stringify(
            input.sourceStamp,
          )}`,
  });
  if (parsed === null) {
    return { fresh: false, product, clauses };
  }

  // Rule 1b: the stamp names THIS product.
  clauses.push({
    id: "source-stamp-product-matches",
    ok: parsed.product === product,
    detail:
      parsed.product === product
        ? `${product} matches`
        : `channel product ${product} but stamp names ${parsed.product}`,
  });

  // Rule 2: the named stamp exists on disk.
  const exists = Array.isArray(input.stampsOnDisk) && input.stampsOnDisk.includes(input.sourceStamp);
  clauses.push({
    id: "source-stamp-exists-on-disk",
    ok: exists,
    detail: exists
      ? `${input.sourceStamp} is present under releases/desktop-flash/`
      : `stamp ${input.sourceStamp} does not exist on disk (freshness cannot be proven)`,
  });

  // Rule 3: sourceStamp === the advertised current stamp.
  const hasCurrent = typeof input.currentStamp === "string" && input.currentStamp !== "";
  const matchesCurrent = hasCurrent && input.sourceStamp === input.currentStamp;
  clauses.push({
    id: "source-stamp-is-current",
    ok: matchesCurrent,
    detail: matchesCurrent
      ? `${input.sourceStamp} is the advertised current stamp`
      : `packed from ${input.sourceStamp} but the product points at ${
          input.currentStamp ?? "(no pointer)"
        } — STALE`,
  });

  // Rule 4: releaseId agrees with the stamp token.
  clauses.push({
    id: "release-id-matches-stamp",
    ok: input.releaseId === parsed.releaseId,
    detail:
      input.releaseId === parsed.releaseId
        ? `releaseId ${input.releaseId} matches`
        : `releaseId ${input.releaseId} != stamp token ${parsed.releaseId}`,
  });

  // Rule 5: unixEpoch agrees with the stamp timestamp.
  clauses.push({
    id: "unix-epoch-matches-stamp",
    ok: input.unixEpoch === parsed.unixEpoch,
    detail:
      input.unixEpoch === parsed.unixEpoch
        ? `unixEpoch ${String(input.unixEpoch)} matches`
        : `unixEpoch ${String(input.unixEpoch)} != stamp epoch ${String(parsed.unixEpoch)}`,
  });

  return { fresh: clauses.every((c) => c.ok), product, clauses };
}

/**
 * Collapse freshness results into the gate's clause vocabulary: a single
 * `channel-freshness` clause that is ok iff every channel is fresh, with a
 * per-channel account in the detail (so a failure names exactly which channel
 * drifted and why).
 */
export function freshnessClause(results) {
  const failures = results.filter((r) => !r.fresh);
  return {
    id: "channel-freshness",
    description: "every packed channel's sourceStamp matches the stamp on disk",
    ok: failures.length === 0,
    detail:
      failures.length === 0
        ? `all ${String(results.length)} packed channel(s) are fresh`
        : failures
            .map((r) => {
              const first = r.clauses.find((c) => !c.ok);
              return `${r.product}: ${first?.detail ?? "not fresh"}`;
            })
            .join("; "),
  };
}
