#!/usr/bin/env node
/**
 * channel-signature.mjs — accept a SIGNED CHANNEL ROOT, and fail closed.
 *
 * T-WEBINSTALL-SIGNED-CHANNEL-ROOT. Until this module the only authenticity
 * mechanism in this tree was a CHECKED-IN CONSTANT: `docs/expected-anchors.json`
 * pins `avb_pkmd.bin` by digest (D-035/D-036) and `trust-anchor.mjs` says so
 * plainly ("checked-in, review-gated; not a signed root"). That is honest for a
 * dev channel, but it means the installer could never ACCEPT a signed root at
 * all — there was no code path that verifies a cryptographic signature over the
 * channel metadata, so nothing could ever be production-authenticated.
 *
 * THE SCHEME IS THE PACKER'S, NOT A NEW ONE. `pack-webinstall-channel.sh`
 * already refuses `CHANNEL=production` unless a `.sig` and an `allowed_signers`
 * file are present, and verifies with:
 *
 *   ssh-keygen -Y verify -f <allowed_signers> -I guardtalk-channel \
 *       -n "factory images" -s <sig> < <payload>
 *
 * This module performs the SAME verification (same primitive, same principal,
 * same namespace, same payload convention — `<sig>` minus its `.sig` suffix)
 * and adds the two things the packer's one-file check could not express:
 *
 *   1. THE SIGNATURE COVERS THE CHANNEL ROOT, NOT ONE FILE. The payload is
 *      `channel-root.txt`, a canonical statement that binds BOTH
 *      `manifest.json` and `SHA256SUMS` by digest:
 *
 *          guardtalk-channel-root/1
 *          product <product>
 *          channel <channel>
 *          manifest.json <sha256>
 *          SHA256SUMS <sha256>
 *
 *      `SHA256SUMS` transitively binds every artifact (including
 *      `avb_pkmd.bin`), and `manifest.json` binds the machine-readable
 *      contract, so one signature covers the whole channel root.
 *
 *   2. THE STATEMENT MUST DESCRIBE THE BYTES ON DISK. A signature over a
 *      statement is worthless if the statement is not re-derived: a forger
 *      could sign a statement about different bytes. So the statement is
 *      PARSED, the digests are RECOMPUTED from the channel directory, and a
 *      mismatch is a failure — the signature then authenticates nothing that
 *      is actually shipped.
 *
 * TRUST COMES FROM OUTSIDE THE CHANNEL. A trust list that ships INSIDE the
 * channel directory it vouches for is self-signed: an attacker who can write
 * the channel writes both. So the accepted trust list is out-of-band, at
 * `<installer>/docs/expected-allowed-signers`, and it must SCOPE the principal
 * to the signature namespace (`namespaces="factory images"`). A channel-local
 * `allowed_signers` (the shape `CHANNEL=production` packing produces) is
 * recorded as `channel-local` and NEVER raises the mode to `signed-root`; it
 * must be corroborated by the out-of-band copy.
 *
 * FAIL CLOSED: a missing statement, a missing signature, a malformed statement,
 * a statement that disagrees with the bytes, a missing/over-broad/self-signed
 * trust list, a trust list carrying private key material, a missing
 * `ssh-keygen`, a timeout, or a non-zero verify exit are ALL failures — never
 * "unsigned, so fine".
 *
 * WHAT THIS PROVES AND WHAT IT DOES NOT: a `verified` result proves the channel
 * metadata was signed by a key the out-of-band trust list names, and that the
 * signed statement describes the bytes on disk. It does NOT prove the key
 * belongs to whoever you think it does (that is the trust list's claim), it
 * does NOT prove the images boot, and it never means a live flash happened.
 * `BOOT_VERIFIED=false`, `LIVE_FLASH_CLAIMED=false`.
 */

import { spawnSync } from "node:child_process";
import { createHash } from "node:crypto";
import { existsSync, readFileSync, statSync } from "node:fs";
import { join } from "node:path";

/** Schema marker the signed statement must declare. */
export const SIGNED_ROOT_SCHEMA = "guardtalk-channel-root/1";

/** The signed statement, inside the channel dir. */
export const ROOT_STATEMENT_FILE = "channel-root.txt";

/** Its detached signature (ssh-keygen -Y sign writes `<file>.sig`). */
export const ROOT_SIGNATURE_FILE = `${ROOT_STATEMENT_FILE}.sig`;

/** The signature namespace. Same value the packer signs and verifies under. */
export const SIGNATURE_NAMESPACE = "factory images";

/** The principal the trust list must name. Same value the packer passes to -I. */
export const TRUSTED_PRINCIPAL = "guardtalk-channel";

/** Out-of-band trust list (git-tracked, review-gated, OUTSIDE `channels/`). */
export const ALLOWED_SIGNERS_FILE = "expected-allowed-signers";

/** Files the signed statement binds, in canonical order. */
export const ROOT_BOUND_FILES = Object.freeze(["manifest.json", "SHA256SUMS"]);

/** How long a verify subprocess may run before it is treated as a failure. */
export const SIGNATURE_TIMEOUT_MS = 30_000;

/**
 * Statuses a single channel's signed-root check can report.
 *
 * - `verified`    a signature over a statement that matches the bytes verified
 * - `absent`      no signing material at all (fine in a dev channel)
 * - `invalid`     material present, verification failed (statement mismatch,
 *                 bad signature, malformed statement, over-broad trust list)
 * - `untrusted`   material present, but no acceptable out-of-band trust list
 * - `unavailable` the verifier could not run (ssh-keygen missing, timeout)
 */
export const SIGNATURE_STATUS = Object.freeze({
  verified: "verified",
  absent: "absent",
  invalid: "invalid",
  untrusted: "untrusted",
  unavailable: "unavailable",
});

const SHA256_RE = /^[0-9a-f]{64}$/;
const PRODUCT_RE = /^[a-z0-9][a-z0-9._-]*$/;

/** sha256 of a Buffer/string, lowercase hex. */
function sha256Hex(bytes) {
  return createHash("sha256").update(bytes).digest("hex");
}

function readIfPresent(path) {
  if (!existsSync(path)) return null;
  try {
    if (!statSync(path).isFile()) return null;
    return readFileSync(path);
  } catch {
    return null;
  }
}

/**
 * Build the canonical root statement. Deterministic: the same channel bytes
 * always produce the same statement, so a signer can re-derive exactly what was
 * signed from a checkout.
 *
 * @param {{product:string, channel:string, digests:Record<string,string>}} input
 * @returns {string}
 */
export function buildRootStatement({ product, channel, digests }) {
  const lines = [SIGNED_ROOT_SCHEMA, `product ${product}`, `channel ${channel}`];
  for (const name of ROOT_BOUND_FILES) {
    lines.push(`${name} ${digests[name]}`);
  }
  return `${lines.join("\n")}\n`;
}

/**
 * Parse a root statement. Strict: unknown/duplicate/missing fields are a
 * problem, never silently dropped.
 *
 * @param {string} text
 * @returns {{ok:boolean, problem:string|null, product:string|null,
 *   channel:string|null, digests:Record<string,string>}}
 */
export function parseRootStatement(text) {
  const digests = {};
  if (typeof text !== "string") {
    return { ok: false, problem: "root statement is not text", product: null, channel: null, digests };
  }
  const lines = text.split("\n");
  if (lines.length > 0 && lines[lines.length - 1] === "") lines.pop();
  if (lines[0] !== SIGNED_ROOT_SCHEMA) {
    return {
      ok: false,
      problem: `root statement does not declare ${SIGNED_ROOT_SCHEMA} (first line is ${JSON.stringify(lines[0] ?? "")})`,
      product: null,
      channel: null,
      digests,
    };
  }
  let product = null;
  let channel = null;
  const seen = new Set();
  for (const line of lines.slice(1)) {
    const [key, value, ...rest] = line.split(" ");
    if (key === undefined || value === undefined || rest.length > 0) {
      return { ok: false, problem: `malformed root statement line ${JSON.stringify(line)}`, product, channel, digests };
    }
    if (seen.has(key)) {
      return { ok: false, problem: `duplicate root statement field ${JSON.stringify(key)}`, product, channel, digests };
    }
    seen.add(key);
    if (key === "product") {
      if (!PRODUCT_RE.test(value)) {
        return { ok: false, problem: `root statement product ${JSON.stringify(value)} is not a product token`, product, channel, digests };
      }
      product = value;
    } else if (key === "channel") {
      if (!PRODUCT_RE.test(value)) {
        return { ok: false, problem: `root statement channel ${JSON.stringify(value)} is not a channel token`, product, channel, digests };
      }
      channel = value;
    } else if (ROOT_BOUND_FILES.includes(key)) {
      if (!SHA256_RE.test(value)) {
        return { ok: false, problem: `root statement digest for ${key} is not a sha256: ${JSON.stringify(value)}`, product, channel, digests };
      }
      digests[key] = value;
    } else {
      return { ok: false, problem: `root statement names an unexpected file ${JSON.stringify(key)}`, product, channel, digests };
    }
  }
  if (product === null) {
    return { ok: false, problem: "root statement declares no product", product, channel, digests };
  }
  if (channel === null) {
    return { ok: false, problem: "root statement declares no channel", product, channel, digests };
  }
  for (const name of ROOT_BOUND_FILES) {
    if (typeof digests[name] !== "string") {
      return { ok: false, problem: `root statement does not bind ${name}`, product, channel, digests };
    }
  }
  return { ok: true, problem: null, product, channel, digests };
}

/**
 * Structural check of an `allowed_signers` trust list.
 *
 * Requires EVERY line naming our principal to carry `namespaces="…"` that
 * includes the signature namespace. An entry without the option lets one key's
 * signatures be minted for any protocol namespace, which is signature reuse
 * across purposes; the packer's `-n "factory images"` check still catches a
 * wrong namespace at verify time, so this is defence in depth, but an
 * unscoped trust list is not a reviewed trust list and is refused.
 *
 * @param {string} text
 * @returns {{ok:boolean, problem:string|null, principals:string[]}}
 */
export function checkAllowedSigners(text) {
  if (typeof text !== "string") {
    return { ok: false, problem: "trust list is not text", principals: [] };
  }
  if (/BEGIN (RSA |EC |OPENSSH |PGP )?PRIVATE KEY/.test(text)) {
    return { ok: false, problem: "trust list contains PRIVATE KEY material — a trust list is public keys only", principals: [] };
  }
  const principals = [];
  let matched = 0;
  for (const raw of text.split("\n")) {
    const line = raw.trim();
    if (line === "" || line.startsWith("#")) continue;
    const fields = line.split(/\s+/);
    const principal = fields[0];
    principals.push(principal);
    if (principal !== TRUSTED_PRINCIPAL) continue;
    matched += 1;
    const ns = /namespaces="([^"]*)"/.exec(line);
    if (ns === null) {
      return {
        ok: false,
        problem: `trust list entry for ${TRUSTED_PRINCIPAL} has no namespaces="…" option — it is not scoped to ${JSON.stringify(SIGNATURE_NAMESPACE)}`,
        principals,
      };
    }
    if (!ns[1].split(",").map((s) => s.trim()).includes(SIGNATURE_NAMESPACE)) {
      return {
        ok: false,
        problem: `trust list entry for ${TRUSTED_PRINCIPAL} is scoped to ${JSON.stringify(ns[1])}, not ${JSON.stringify(SIGNATURE_NAMESPACE)}`,
        principals,
      };
    }
  }
  if (matched === 0) {
    return {
      ok: false,
      problem: `trust list names no ${TRUSTED_PRINCIPAL} principal — nothing in it can authenticate a channel root`,
      principals,
    };
  }
  return { ok: true, problem: null, principals };
}

/**
 * Run `ssh-keygen -Y verify`. Injected so a test can simulate a missing
 * binary / a timeout without uninstalling ssh-keygen.
 *
 * @param {string[]} args
 * @param {Buffer} input  the signed payload (the statement), fed on stdin
 * @returns {{status:number|null, stdout:string, stderr:string, error:string|null}}
 */
export function defaultVerifyRunner(args, input) {
  const result = spawnSync("ssh-keygen", args, {
    input,
    encoding: "utf8",
    timeout: SIGNATURE_TIMEOUT_MS,
    maxBuffer: 1024 * 1024,
  });
  const failure = result.error;
  if (failure !== undefined && failure !== null) {
    const code = /** @type {{code?:string}} */ (failure).code;
    return {
      status: null,
      stdout: String(result.stdout ?? ""),
      stderr: String(result.stderr ?? ""),
      error:
        code === "ENOENT"
          ? "ssh-keygen is not installed — a signed root cannot be verified without it"
          : `ssh-keygen could not run: ${failure.message}`,
    };
  }
  return {
    status: result.status,
    stdout: String(result.stdout ?? ""),
    stderr: String(result.stderr ?? ""),
    error: null,
  };
}

/** Resolve the trust list: explicit path, then out-of-band, then channel-local. */
function resolveTrustList(channelDir, installerRoot, explicitPath) {
  if (typeof explicitPath === "string" && explicitPath !== "") {
    return { path: explicitPath, source: "explicit", text: readIfPresent(explicitPath) };
  }
  const outOfBand = join(installerRoot, "docs", ALLOWED_SIGNERS_FILE);
  const outOfBandText = readIfPresent(outOfBand);
  if (outOfBandText !== null) {
    return { path: outOfBand, source: "out-of-band", text: outOfBandText };
  }
  const local = join(channelDir, "allowed_signers");
  const localText = readIfPresent(local);
  if (localText !== null) {
    return { path: local, source: "channel-local", text: localText };
  }
  return { path: null, source: null, text: null };
}

/**
 * Verify ONE packed channel's signed root.
 *
 * @param {{
 *   dir: string,                       // absolute channel dir
 *   product: string,                   // channel dir name
 *   installerRoot: string,             // for the out-of-band trust list
 *   allowedSignersPath?: string|null,  // explicit trust list (CLI/test)
 *   run?: typeof defaultVerifyRunner,
 * }} input
 * @returns {{
 *   product:string, status:string, verified:boolean,
 *   detail:string, statement:string|null, signature:string|null,
 *   trustSource:string|null, trustList:string|null, signer:string|null,
 *   namespace:string|null, channel:string|null, digests:Record<string,string>,
 * }}
 */
export function verifyChannelSignature(input) {
  const { dir, product, installerRoot } = input;
  const run = input.run ?? defaultVerifyRunner;
  const blank = {
    product,
    status: SIGNATURE_STATUS.absent,
    verified: false,
    detail: "",
    statement: null,
    signature: null,
    trustSource: null,
    trustList: null,
    signer: null,
    namespace: null,
    channel: null,
    digests: {},
  };
  const base = { ...blank, statement: join(dir, ROOT_STATEMENT_FILE), signature: join(dir, ROOT_SIGNATURE_FILE) };

  if (!PRODUCT_RE.test(String(product))) {
    return { ...base, status: SIGNATURE_STATUS.invalid, detail: `channel directory name ${JSON.stringify(product)} is not a product token` };
  }

  // (1) Bind the statement to the bytes that are actually shipped.
  const digests = {};
  for (const name of ROOT_BOUND_FILES) {
    const bytes = readIfPresent(join(dir, name));
    if (bytes === null) {
      return { ...base, status: SIGNATURE_STATUS.invalid, detail: `${name} is missing from ${dir} — the channel root cannot be bound (fail closed)` };
    }
    digests[name] = sha256Hex(bytes);
  }

  // (2) The signed statement must exist.
  const statementBytes = readIfPresent(base.statement);
  if (statementBytes === null) {
    return {
      ...base,
      digests,
      detail: `${ROOT_STATEMENT_FILE} is absent — this channel carries no signed root`,
    };
  }
  const statementText = statementBytes.toString("utf8");
  const parsed = parseRootStatement(statementText);
  if (!parsed.ok) {
    return { ...base, digests, status: SIGNATURE_STATUS.invalid, detail: parsed.problem ?? "root statement is malformed" };
  }

  // (3) The statement must describe THESE bytes.
  if (parsed.product !== product) {
    return {
      ...base,
      digests,
      channel: parsed.channel,
      status: SIGNATURE_STATUS.invalid,
      detail: `statement is for product ${JSON.stringify(parsed.product)} but this channel is ${JSON.stringify(product)} — a signed root cannot be replayed onto another product`,
    };
  }
  const drifted = ROOT_BOUND_FILES.filter((name) => parsed.digests[name] !== digests[name]);
  if (drifted.length > 0) {
    return {
      ...base,
      digests,
      channel: parsed.channel,
      status: SIGNATURE_STATUS.invalid,
      detail: `the signed statement does not describe the bytes on disk: ${drifted
        .map((name) => `${name} signed ${parsed.digests[name]}, on disk ${digests[name]}`)
        .join("; ")}`,
    };
  }
  // The manifest's own channel claim must agree with the signed statement, so a
  // "production" statement cannot ride on a manifest that says "dev".
  const manifestText = readIfPresent(join(dir, "manifest.json"));
  if (manifestText !== null) {
    let declared = null;
    try {
      const doc = JSON.parse(manifestText.toString("utf8"));
      declared = typeof doc?.channel === "string" ? doc.channel : null;
    } catch {
      declared = null;
    }
    if (declared !== null && declared !== parsed.channel) {
      return {
        ...base,
        digests,
        channel: parsed.channel,
        status: SIGNATURE_STATUS.invalid,
        detail: `statement is for channel ${JSON.stringify(parsed.channel)} but manifest.json declares ${JSON.stringify(declared)} — inconsistent channel root`,
      };
    }
  }

  // (4) The detached signature must exist.
  const sigBytes = readIfPresent(base.signature);
  if (sigBytes === null) {
    return {
      ...base,
      digests,
      channel: parsed.channel,
      status: SIGNATURE_STATUS.invalid,
      detail: `${ROOT_STATEMENT_FILE} is present but ${ROOT_SIGNATURE_FILE} is absent — a statement without a signature authenticates nothing (fail closed)`,
    };
  }

  // (5) The trust list must come from OUTSIDE the channel it vouches for.
  const trust = resolveTrustList(dir, installerRoot, input.allowedSignersPath ?? null);
  const withTrust = { ...base, digests, channel: parsed.channel, trustSource: trust.source, trustList: trust.path };
  if (trust.text === null) {
    const explicit = input.allowedSignersPath ?? null;
    return {
      ...withTrust,
      status: SIGNATURE_STATUS.untrusted,
      detail:
        typeof explicit === "string" && explicit !== ""
          ? `the explicit trust list ${explicit} is absent or unreadable — a signed root cannot be authenticated (fail closed)`
          : `no trust list: ${join(installerRoot, "docs", ALLOWED_SIGNERS_FILE)} is absent and the channel ships no allowed_signers — a signed root cannot be authenticated (fail closed)`,
    };
  }
  if (trust.source === "channel-local") {
    return {
      ...withTrust,
      status: SIGNATURE_STATUS.untrusted,
      detail: `the only trust list is ${trust.path}, INSIDE the channel it vouches for — self-signed trust. Place the reviewed list at ${join(installerRoot, "docs", ALLOWED_SIGNERS_FILE)} (fail closed)`,
    };
  }
  const signers = checkAllowedSigners(trust.text.toString("utf8"));
  if (!signers.ok) {
    return { ...withTrust, status: SIGNATURE_STATUS.invalid, detail: signers.problem ?? "trust list is unusable" };
  }

  // (6) The cryptographic check — the packer's exact invocation.
  const runResult = run(
    [
      "-Y",
      "verify",
      "-f",
      /** @type {string} */ (trust.path),
      "-I",
      TRUSTED_PRINCIPAL,
      "-n",
      SIGNATURE_NAMESPACE,
      "-s",
      base.signature,
    ],
    statementBytes,
  );
  if (runResult.error !== null) {
    return { ...withTrust, status: SIGNATURE_STATUS.unavailable, detail: runResult.error };
  }
  if (runResult.status !== 0) {
    const why = (runResult.stderr || runResult.stdout || "").trim().split("\n").filter(Boolean).slice(-1)[0] ?? "";
    return {
      ...withTrust,
      status: SIGNATURE_STATUS.invalid,
      detail: `ssh-keygen -Y verify rejected ${ROOT_SIGNATURE_FILE} (exit ${String(runResult.status)})${
        why === "" ? "" : `: ${why}`
      }`,
    };
  }

  return {
    ...withTrust,
    status: SIGNATURE_STATUS.verified,
    verified: true,
    signer: TRUSTED_PRINCIPAL,
    namespace: SIGNATURE_NAMESPACE,
    detail: `signature verified against ${trust.source} trust list (${trust.path}); signed statement describes manifest.json + SHA256SUMS on disk`,
  };
}

/**
 * Verify every packed channel's signed root and aggregate.
 *
 * `required` is the CALLER's policy (a mode that demands a signature). It is
 * never inferred from the channel's own documents: a channel that says "I am
 * signed" is a claim, and claims are what this module exists to check.
 *
 * @param {{
 *   channels: Map<string, {packed:boolean}|null|undefined>,
 *   channelsRoot: string,            // absolute channels root (follows the drill root)
 *   installerRoot: string,
 *   required?: boolean,
 *   allowedSignersPath?: string|null,
 *   run?: typeof defaultVerifyRunner,
 * }} input
 */
export function verifyChannelSignatures({
  channels,
  channelsRoot,
  installerRoot,
  required = false,
  allowedSignersPath = null,
  run = undefined,
}) {
  const results = [];
  for (const [product, probed] of [...channels.entries()].sort((a, b) => a[0].localeCompare(b[0]))) {
    if (probed === null || probed === undefined || probed.packed !== true) continue;
    results.push(
      verifyChannelSignature({
        dir: join(channelsRoot, product),
        product,
        installerRoot,
        allowedSignersPath,
        run,
      }),
    );
  }

  const anyMaterial = results.some((r) => r.status !== SIGNATURE_STATUS.absent);
  const failed = results.filter((r) => r.status !== SIGNATURE_STATUS.verified && r.status !== SIGNATURE_STATUS.absent);
  const verified = results.length > 0 && failed.length === 0 && results.every((r) => r.status === SIGNATURE_STATUS.verified);

  let status;
  if (results.length === 0) status = SIGNATURE_STATUS.absent;
  else if (verified) status = SIGNATURE_STATUS.verified;
  else if (failed.some((r) => r.status === SIGNATURE_STATUS.invalid)) status = SIGNATURE_STATUS.invalid;
  else if (failed.some((r) => r.status === SIGNATURE_STATUS.untrusted)) status = SIGNATURE_STATUS.untrusted;
  else if (failed.some((r) => r.status === SIGNATURE_STATUS.unavailable)) status = SIGNATURE_STATUS.unavailable;
  else status = SIGNATURE_STATUS.absent;

  const detail = (() => {
    if (results.length === 0) return "no packed channels to sign";
    if (verified) {
      const signer = results[0]?.signer ?? TRUSTED_PRINCIPAL;
      const ns = results[0]?.namespace ?? SIGNATURE_NAMESPACE;
      return `all ${String(results.length)} packed channel root(s) verify (principal ${signer}, namespace ${JSON.stringify(ns)})`;
    }
    if (!anyMaterial) {
      return required
        ? "THIS MODE REQUIRES A SIGNED CHANNEL ROOT and none of the packed channels carries one — unsigned, fail closed"
        : "no packed channel carries a signed root — the review-gated pins remain the only authenticity mechanism";
    }
    return failed
      .map((r) => `${r.product}: ${r.detail}`)
      .join("; ");
  })();

  // A signed root must name ONE channel across the packed set; a mixed set is
  // reported as unknown rather than picking an arbitrary member.
  const channelsNamed = [...new Set(results.map((r) => r.channel).filter((c) => typeof c === "string"))];
  const channel = channelsNamed.length === 1 ? channelsNamed[0] : null;

  return {
    status,
    verified,
    required,
    /** The mechanism a mode surface may report. Never "signed-root" unless verified. */
    mechanism: verified ? "signed-root" : "none",
    /** The evidence `anchor-mode.mjs` accepts — produced ONLY by a verifier. */
    verification: verified
      ? { mechanism: "signed-root", verified: true, channel }
      : { mechanism: "signed-root", verified: false },
    anyMaterial,
    trustSource: results.find((r) => r.trustSource !== null)?.trustSource ?? null,
    signer: verified ? (results[0]?.signer ?? null) : null,
    namespace: verified ? (results[0]?.namespace ?? null) : null,
    detail,
    channels: results.map((r) => ({
      product: r.product,
      status: r.status,
      verified: r.verified,
      detail: r.detail,
      statement: r.statement,
      signature: r.signature,
      trustSource: r.trustSource,
      trustList: r.trustList,
      channel: r.channel,
    })),
  };
}
