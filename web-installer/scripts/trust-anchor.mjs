#!/usr/bin/env node
/**
 * trust-anchor.mjs — the OUT-OF-BAND pin on every channel's AVB public key.
 *
 * T-WEBINSTALL-TRUST-ANCHOR-VERIFICATION. `channels/<product>/avb_pkmd.bin` is
 * the AVB public key: the trust anchor that makes a flashed image verifiable on
 * device. Before this module the only check on it was "the bytes hash to the
 * digest recorded in the channel's OWN SHA256SUMS" — which proves INTERNAL
 * SELF-CONSISTENCY, never authenticity: swap the bytes AND the sums together
 * and the check still passes. A forgery that replaced all four anchors with
 * `head -c 1032 /dev/urandom` and recomputed manifest.json + SHA256SUMS passed
 * the readiness gate and the whole channel-complete suite.
 *
 * The fix is an anchor that is NOT derived from the tree it is verifying: the
 * checked-in `docs/expected-anchors.json` pin. This module is the ONE
 * implementation of "does the channel match its pin", usable from the gate
 * (plain `node`) and from the tests (`tsx`).
 *
 * WHAT THIS PIN DOES AND DOES NOT PROVE (stated plainly, not implied):
 *   - It proves the shipped `avb_pkmd.bin` is byte-identical to a digest a
 *     human reviewed in a PR. Changing a channel anchor without a matching,
 *     reviewable diff to `docs/expected-anchors.json` now FAILS the gate.
 *   - It does NOT prove the pin is the key the images were actually signed
 *     with: it is not a signature and nothing cryptographically binds it to
 *     the vbmeta images. There is no signed root here.
 *   - `CHANNEL=dev` is hash-only (no channel signature at all), so this pin is
 *     a review-gated checked-in constant — NOT GrapheneOS-equivalent (whose
 *     public keys live in signed release metadata) and NOT a signed root.
 *
 * The pin file carries its own repair: key material and the shipped anchors
 * are NOT in this repo history (the workspace root is not a git repo, the
 * channels are not tracked), so a reviewer cannot always read the original
 * diff. `docs/expected-anchors.json` therefore records, per pin, the digest of
 * the release-stamp `avb_pkmd.bin` the channel was packed from. That value is
 * still a checked-in constant (same trust model as the pin itself — it is
 * corroboration, not an independent proof), but it makes an accidental repack
 * with a wrong key visible as "pin and source stamp disagree", and it names
 * exactly which file a reviewer should re-derive.
 *
 * FAIL CLOSED: a missing pin, a missing anchor file, an unreadable anchor, a
 * size mismatch, or a digest mismatch is a failure — never "unpinned, so ok".
 *
 * HONESTY: BOOT_VERIFIED=false. An anchor match says "this is the pinned
 * public key", never "these images boot".
 */

/** The schema marker the pin file must declare. */
export const ANCHORS_SCHEMA = "expected-anchors/1";

/** Anchor file name inside every packed channel. */
export const ANCHOR_FILE = "avb_pkmd.bin";

const SHA256_RE = /^[0-9a-f]{64}$/;

/**
 * One anchor's verdict. Pure: all inputs are values, no I/O.
 *
 * @param {string} product
 * @param {{sha256?:unknown, size?:unknown}} observed  what the channel ships
 * @param {{file?:unknown, sha256?:unknown, size?:unknown, sourceStampSha256?:unknown}|undefined} pin
 *        the out-of-band pin for this product (undefined when absent)
 * @returns {{pinned:boolean, product:string, clauses:{id:string,ok:boolean,detail:string}[]}}
 */
export function checkTrustAnchor(product, observed, pin) {
  const clauses = [];

  // Rule 1: a pin exists for this product. Absence is NOT a pass.
  const hasPin = pin !== undefined && pin !== null && typeof pin === "object";
  clauses.push({
    id: "anchor-pinned",
    ok: hasPin,
    detail: hasPin
      ? `${product} has an out-of-band pin`
      : `${product} has NO out-of-band pin in docs/expected-anchors.json — unauthenticated`,
  });
  if (!hasPin) return { pinned: false, product, clauses };

  // Rule 2: the pin names the file it pins (it must be the AVB key file).
  clauses.push({
    id: "anchor-pin-names-key-file",
    ok: pin.file === ANCHOR_FILE,
    detail:
      pin.file === ANCHOR_FILE
        ? `pin names ${ANCHOR_FILE}`
        : `pin.file is ${JSON.stringify(pin.file)} — expected ${ANCHOR_FILE}`,
  });

  // Rule 3: the pin itself is well formed (a malformed pin cannot vouch).
  const pinWellFormed =
    typeof pin.sha256 === "string" &&
    SHA256_RE.test(pin.sha256) &&
    Number.isInteger(pin.size) &&
    pin.size > 0;
  clauses.push({
    id: "anchor-pin-well-formed",
    ok: pinWellFormed,
    detail: pinWellFormed
      ? `pin ${pin.sha256} (${String(pin.size)} bytes)`
      : `pin is malformed: sha256=${JSON.stringify(pin.sha256)} size=${JSON.stringify(pin.size)}`,
  });

  // Rule 4: the shipped size equals the pinned size.
  const sizeOk = observed.size === pin.size;
  clauses.push({
    id: "anchor-size-matches",
    ok: sizeOk,
    detail: sizeOk
      ? `size ${String(observed.size)} matches the pin`
      : `size ${String(observed.size)} != pinned ${String(pin.size)}`,
  });

  // Rule 5: the shipped digest equals the pinned digest. The actual gate.
  const observedDigest =
    typeof observed.sha256 === "string" ? observed.sha256.toLowerCase() : null;
  const digestOk = pinWellFormed && observedDigest === pin.sha256;
  clauses.push({
    id: "anchor-sha256-matches",
    ok: digestOk,
    detail: digestOk
      ? `sha256 ${String(observedDigest)} matches the out-of-band pin`
      : `sha256 ${observedDigest ?? "(unreadable)"} != pinned ${
          typeof pin.sha256 === "string" ? pin.sha256 : "(malformed pin)"
        } — UNPINNED BYTES (self-consistent, unauthenticated)`,
  });

  return { pinned: clauses.every((c) => c.ok), product, clauses };
}

/**
 * Parse + structurally validate the pin document. Returns the pins keyed by
 * product, or a `problem` string when the document cannot be trusted.
 *
 * @param {unknown} document
 * @returns {{channel:string|null, pins:Map<string, Record<string, unknown>>, problem:string|null}}
 */
export function parseAnchorPins(document) {
  const pins = new Map();
  if (typeof document !== "object" || document === null) {
    return { channel: null, pins, problem: "pin document is not an object" };
  }
  const doc = /** @type {Record<string, unknown>} */ (document);
  if (doc.schemaVersion !== ANCHORS_SCHEMA) {
    return {
      channel: null,
      pins,
      problem: `pin document schemaVersion is ${JSON.stringify(doc.schemaVersion)} — expected ${ANCHORS_SCHEMA}`,
    };
  }
  const anchors = doc.anchors;
  if (typeof anchors !== "object" || anchors === null || Array.isArray(anchors)) {
    return { channel: null, pins, problem: "pin document has no `anchors` object" };
  }
  for (const [product, raw] of Object.entries(anchors)) {
    if (typeof raw !== "object" || raw === null) {
      return { channel: null, pins, problem: `pin for ${product} is not an object` };
    }
    pins.set(product, /** @type {Record<string, unknown>} */ (raw));
  }
  if (pins.size === 0) {
    return { channel: null, pins, problem: "pin document lists no anchors" };
  }
  return { channel: typeof doc.channel === "string" ? doc.channel : null, pins, problem: null };
}

/**
 * Read the pin document from disk. A missing/unparseable file is NOT thrown:
 * it becomes `problem` text, and every anchor then fails closed.
 *
 * @param {string} path
 * @param {(path:string)=>string} readText  injected so the test can read a fixture
 * @returns {{channel:string|null, pins:Map<string, Record<string, unknown>>, problem:string|null}}
 */
export function loadAnchorPinsFromText(path, text) {
  if (text === null || text === undefined) {
    return {
      channel: null,
      pins: new Map(),
      problem: `anchor pin file not found: ${path} — the AVB trust anchor cannot be verified (fail closed)`,
    };
  }
  let document;
  try {
    document = JSON.parse(text);
  } catch (err) {
    return {
      channel: null,
      pins: new Map(),
      problem: `anchor pin file is not JSON: ${path} (${err instanceof Error ? err.message : "parse error"})`,
    };
  }
  return parseAnchorPins(document);
}

/**
 * Evaluate the trust-anchor invariant for a set of packed channels.
 *
 * @param {ReadonlyMap<string, {sha256:string|null, size:number|null, source?:string}>} observed
 *        product -> digest + size of the bytes the installer would ship
 * @param {{channel:string|null, pins:Map<string, Record<string, unknown>>, problem:string|null}} parsedPins
 * @param {{channel?:string|null}} [options]
 * @returns {{ok:boolean, id:string, description:string, detail:string, results:any[]}}
 */
export function checkTrustAnchors(observed, parsedPins, options = {}) {
  const results = [];
  for (const [product, anchor] of observed) {
    results.push(checkTrustAnchor(product, anchor, parsedPins.pins.get(product)));
  }
  results.sort((a, b) => a.product.localeCompare(b.product));

  const problems = [];
  if (parsedPins.problem !== null) problems.push(parsedPins.problem);
  // A pin for a product that no longer ships is a stale pin, not a pass: the
  // reviewer must see the pin move when the advertised set changes.
  const packedProducts = new Set(results.map((r) => r.product));
  for (const product of parsedPins.pins.keys()) {
    if (!packedProducts.has(product)) {
      problems.push(`${product} is pinned but is not a packed channel (stale pin)`);
    }
  }
  const expectedChannel = options.channel ?? null;
  if (expectedChannel !== null && parsedPins.channel !== expectedChannel) {
    problems.push(
      `pin channel is ${JSON.stringify(parsedPins.channel)} but the tree ships ${JSON.stringify(expectedChannel)}`,
    );
  }
  const unpinned = results.filter((r) => !r.pinned);
  const ok = results.length > 0 && problems.length === 0 && unpinned.length === 0;

  const detail = ok
    ? `all ${String(results.length)} packed channel(s) match their out-of-band AVB anchor pins`
    : [
        ...problems,
        ...unpinned.map((r) => {
          const first = r.clauses.find((c) => !c.ok);
          return `${r.product}: ${first?.detail ?? "anchor mismatch"}`;
        }),
      ].join("; ");

  return {
    ok,
    id: "trust-anchor",
    description:
      "every packed channel's avb_pkmd.bin matches the out-of-band pin in docs/expected-anchors.json",
    detail: detail.length > 0 ? detail : "no packed channels to pin",
    results,
  };
}

/**
 * Reword every `SOURCESTAMP` / `anchor` string a consumer prints so it says
 * what the check actually proves. Kept here (one source) so the wording is
 * tested against the same constant the consumers import.
 */
export const ANCHOR_AUTHENTICITY_WORDING = {
  /** For a channel that matches its pin. */
  authentic: "avb_pkmd.bin authenticated against the out-of-band pin (checked-in, review-gated; not a signed root)",
  /** For a channel whose bytes are only internally consistent. */
  selfConsistent: "internally consistent, unauthenticated",
};
