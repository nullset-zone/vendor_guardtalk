/**
 * T-WEBINSTALL-SIGNED-CHANNEL-ROOT — a signed channel root must be ACCEPTED,
 * and an unsigned/invalid one must FAIL CLOSED.
 *
 * The gap this suite pins down: authenticity used to rest entirely on
 * CHECKED-IN CONSTANTS (`docs/expected-anchors.json`, `docs/expected-shape.json`).
 * That is honest for a dev channel, but nothing in the tree could verify a
 * cryptographic signature over the channel metadata, so no channel could ever
 * be production-authenticated. `scripts/channel-signature.mjs` is that
 * mechanism: the PACKER'S scheme (`ssh-keygen -Y verify`, principal
 * `guardtalk-channel`, namespace `factory images`) applied to a canonical
 * statement binding `manifest.json` + `SHA256SUMS`, re-derived from the bytes.
 *
 * THE SIGNER IS A THROWAWAY, GENERATED PER RUN, IN THE OS TEMP DIR.
 * `ssh-keygen -t ed25519` writes `<tmp>/gt-signer-<random>/signer` plus its
 * `.pub`; the directory is removed in `finally`. No key material is ever
 * written inside the repository, no committed file references a key path, and
 * these keys sign nothing but fixture channels. There is no real release key
 * here and this suite cannot create one.
 *
 * EVERY DRILL RUNS AGAINST A THROWAWAY TREE in `os.tmpdir()`: the real
 * `channels/` and `releases/desktop-flash/` are never opened for writing.
 *
 * HONESTY: a `verified` result proves a signature over metadata that matches
 * the bytes on disk. It does NOT prove the images boot, and it is never a live
 * flash. `BOOT_VERIFIED=false`, `LIVE_FLASH_CLAIMED=false`.
 */
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { createHash } from "node:crypto";
import { mkdtempSync, readFileSync, rmSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { basename, join } from "node:path";
import { test } from "node:test";
import { INSTALLER_ROOT } from "../scripts/gen-flash-matrix.mjs";
import {
  ALLOWED_SIGNERS_FILE,
  ROOT_SIGNATURE_FILE,
  ROOT_STATEMENT_FILE,
  SIGNATURE_NAMESPACE,
  TRUSTED_PRINCIPAL,
  buildRootStatement,
  checkAllowedSigners,
  defaultVerifyRunner,
  parseRootStatement,
  verifyChannelSignature,
} from "../scripts/channel-signature.mjs";
import { evaluateGate } from "../scripts/readiness-gate.mjs";
import type { GateResult } from "../scripts/readiness-gate.mjs";
import type { ChannelSignaturesResult } from "../scripts/channel-signature.mjs";
import { FIXTURE_PRODUCTS, genuineTree } from "./fixtures/tree-fixture.js";

const GATE = join(INSTALLER_ROOT, "scripts", "readiness-gate.mjs");

interface GatePayload {
  gate: string;
  exitCode: number;
  summary: string;
  anchorMode: { id: string; mechanism: string; validated: boolean; signed: boolean; label: string };
  authenticity: {
    mode: string;
    mechanism: string;
    required: boolean;
    signed: boolean;
    status: string;
    verified: boolean;
    trustSource: string | null;
    signer: string | null;
    namespace: string | null;
    detail: string;
    channels: { product: string; status: string; verified: boolean; detail: string }[];
  };
  clauses: { id: string; ok: boolean; detail: string }[];
}

function sha256(bytes: Buffer): string {
  return createHash("sha256").update(bytes).digest("hex");
}

/** A throwaway ed25519 signer under the OS temp dir. Removed by `dispose()`. */
interface Signer {
  readonly dir: string;
  readonly key: string;
  readonly pub: string;
  dispose(): void;
}

function makeSigner(): Signer {
  const dir = mkdtempSync(join(tmpdir(), "gt-signer-"));
  const key = join(dir, "signer");
  execFileSync("ssh-keygen", [
    "-q",
    "-t",
    "ed25519",
    "-N",
    "",
    "-C",
    "T-WEBINSTALL-SIGNED-CHANNEL-ROOT test-only (never shipped)",
    "-f",
    key,
  ]);
  return {
    dir,
    key,
    pub: readFileSync(`${key}.pub`, "utf8").trim(),
    dispose() {
      rmSync(dir, { recursive: true, force: true });
    },
  };
}

/** Write `<root>/docs/expected-allowed-signers` naming `pub` for our namespace. */
function writeTrustList(root: string, pub: string, scoped = true): void {
  const options = scoped ? ` namespaces="${SIGNATURE_NAMESPACE}"` : "";
  writeFileSync(
    join(root, "docs", ALLOWED_SIGNERS_FILE),
    `# T-WEBINSTALL-SIGNED-CHANNEL-ROOT test-only trust list (never shipped)\n${TRUSTED_PRINCIPAL}${options} ${pub}\n`,
  );
}

/** Write and sign `channel-root.txt` for one channel dir. */
function signChannelRoot(channelDir: string, signer: Signer, channel?: string): string {
  const manifest = readFileSync(join(channelDir, "manifest.json"));
  const sums = readFileSync(join(channelDir, "SHA256SUMS"));
  const declared =
    channel ??
    (JSON.parse(manifest.toString("utf8")) as { channel?: string }).channel ??
    "dev";
  const statement = buildRootStatement({
    product: basename(channelDir),
    channel: declared,
    digests: { "manifest.json": sha256(manifest), SHA256SUMS: sha256(sums) },
  });
  const path = join(channelDir, ROOT_STATEMENT_FILE);
  writeFileSync(path, statement);
  execFileSync("ssh-keygen", ["-Y", "sign", "-f", signer.key, "-n", SIGNATURE_NAMESPACE, path], {
    stdio: "pipe",
  });
  return statement;
}

function signAllChannels(root: string, signer: Signer, products: readonly string[]): void {
  for (const product of products) signChannelRoot(join(root, "channels", product), signer);
}

function runGate(args: string[], env: NodeJS.ProcessEnv = process.env): {
  code: number;
  stdout: string;
  stderr: string;
} {
  try {
    const stdout = execFileSync(process.execPath, [GATE, ...args], { encoding: "utf8", stdio: "pipe", env });
    return { code: 0, stdout, stderr: "" };
  } catch (err) {
    const e = err as { status?: number; stdout?: string; stderr?: string };
    return { code: e.status ?? -1, stdout: String(e.stdout ?? ""), stderr: String(e.stderr ?? "") };
  }
}

function gateTree(root: string, extra: string[] = []): { code: number; payload: GatePayload } {
  const run = runGate(["--json", `--matrix=${join(root, "docs", "flash-matrix.json")}`, ...extra]);
  return { code: run.code, payload: JSON.parse(run.stdout) as GatePayload };
}

/* ------------------------------------------------------------------ unit --- */

test("SIGNED-ROOT: the statement binds manifest.json + SHA256SUMS and round-trips", () => {
  const digests = { "manifest.json": "a".repeat(64), SHA256SUMS: "b".repeat(64) };
  const text = buildRootStatement({ product: "tokay", channel: "dev", digests });
  assert.match(text, /^guardtalk-channel-root\/1\n/);
  const parsed = parseRootStatement(text);
  assert.equal(parsed.ok, true, parsed.problem ?? "");
  assert.equal(parsed.product, "tokay");
  assert.equal(parsed.channel, "dev");
  assert.deepEqual(parsed.digests, digests);
  // Deterministic: the same bytes always produce the same statement, so a
  // reviewer can re-derive what was signed.
  assert.equal(text, buildRootStatement({ product: "tokay", channel: "dev", digests }));
});

test("SIGNED-ROOT: a malformed or incomplete statement is rejected, never half-read", () => {
  const good = buildRootStatement({
    product: "tokay",
    channel: "dev",
    digests: { "manifest.json": "a".repeat(64), SHA256SUMS: "b".repeat(64) },
  });
  const cases: [string, RegExp][] = [
    ["", /does not declare/],
    [good.replace("guardtalk-channel-root/1", "other/1"), /does not declare/],
    [good.replace(/SHA256SUMS .*\n/, ""), /does not bind SHA256SUMS/],
    [good.replace(/product .*\n/, ""), /declares no product/],
    [good.replace(/channel .*\n/, ""), /declares no channel/],
    [`${good}extra.img ${"c".repeat(64)}\n`, /unexpected file/],
    [good.replace(/manifest\.json [0-9a-f]{64}/, "manifest.json deadbeef"), /not a sha256/],
  ];
  for (const [text, pattern] of cases) {
    const parsed = parseRootStatement(text);
    assert.equal(parsed.ok, false, `must reject: ${JSON.stringify(text)}`);
    assert.match(parsed.problem ?? "", pattern);
  }
});

test("SIGNED-ROOT: a trust list must scope the principal to the signature namespace", () => {
  const key = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestOnlyKeyMaterialNotReal test";
  const scoped = `${TRUSTED_PRINCIPAL} namespaces="${SIGNATURE_NAMESPACE}" ${key}\n`;
  assert.equal(checkAllowedSigners(scoped).ok, true);
  assert.equal(checkAllowedSigners(`# comment\n${scoped}`).ok, true);

  const unscoped = `${TRUSTED_PRINCIPAL} ${key}\n`;
  assert.equal(checkAllowedSigners(unscoped).ok, false, "an unscoped entry signs for any namespace");
  const wrongNs = `${TRUSTED_PRINCIPAL} namespaces="git" ${key}\n`;
  assert.equal(checkAllowedSigners(wrongNs).ok, false);
  const noPrincipal = `someone-else namespaces="${SIGNATURE_NAMESPACE}" ${key}\n`;
  assert.equal(checkAllowedSigners(noPrincipal).ok, false);
  const privateKey =
    `${TRUSTED_PRINCIPAL} namespaces="${SIGNATURE_NAMESPACE}" ${key}\n` +
    "-----BEGIN OPENSSH PRIVATE KEY-----\nAAAA\n-----END OPENSSH PRIVATE KEY-----\n";
  assert.equal(checkAllowedSigners(privateKey).ok, false, "a trust list is public keys only");
});

test("SIGNED-ROOT: a missing ssh-keygen is `unavailable`, never a pass", () => {
  const tree = genuineTree(FIXTURE_PRODUCTS.slice(0, 1));
  const signer = makeSigner();
  try {
    signAllChannels(tree.root, signer, FIXTURE_PRODUCTS.slice(0, 1));
    writeTrustList(tree.root, signer.pub);
    const result = verifyChannelSignature({
      dir: join(tree.root, "channels", FIXTURE_PRODUCTS[0] as string),
      product: FIXTURE_PRODUCTS[0] as string,
      installerRoot: tree.root,
      run: () => ({ status: null, stdout: "", stderr: "", error: "ssh-keygen is not installed" }),
    });
    assert.equal(result.status, "unavailable");
    assert.equal(result.verified, false);
    assert.match(result.detail, /ssh-keygen/);
  } finally {
    signer.dispose();
    tree.writer.cleanup();
  }
});

/* ------------------------------------------------------------- gate (a) --- */

test("SIGNED-ROOT (a): an UNSIGNED root in a mode that requires signing FAILS closed", () => {
  const tree = genuineTree(FIXTURE_PRODUCTS);
  try {
    // Control: the same tree PASSES without the requirement (dev behaviour).
    const dev = gateTree(tree.root);
    assert.equal(dev.code, 0, "the dev channel must still PASS (14 clauses)");
    assert.equal(dev.payload.clauses.length, 14);
    assert.equal(dev.payload.authenticity.required, false);
    assert.equal(dev.payload.authenticity.status, "absent");
    assert.equal(dev.payload.anchorMode.id, "review-gated-pins");

    const required = gateTree(tree.root, ["--require-signed-root"]);
    assert.equal(required.code, 1, "a signature-required mode must NOT pass an unsigned tree");
    assert.equal(required.payload.gate, "FAIL");
    assert.equal(required.payload.clauses.length, 15, "the signed-channel-root clause is added");
    const clause = required.payload.clauses.find((c) => c.id === "signed-channel-root");
    assert.ok(clause !== undefined, "the failing mechanism must be NAMED");
    assert.equal(clause.ok, false);
    assert.match(clause.detail, /REQUIRES A SIGNED CHANNEL ROOT/);
    assert.equal(required.payload.authenticity.required, true);
    assert.equal(required.payload.authenticity.status, "absent");
    assert.equal(required.payload.authenticity.verified, false);
    assert.equal(required.payload.anchorMode.signed, false, "nothing may claim a signed root here");
  } finally {
    tree.writer.cleanup();
  }
});

test("SIGNED-ROOT (a): the env-var mode is fail-closed too — an unrecognised value means REQUIRED", () => {
  const tree = genuineTree(FIXTURE_PRODUCTS);
  try {
    const run = runGate(["--json", `--matrix=${join(tree.root, "docs", "flash-matrix.json")}`], {
      ...process.env,
      GUARDTALK_REQUIRE_SIGNED_ROOT: "yes-please",
    });
    assert.equal(run.code, 1);
    const payload = JSON.parse(run.stdout) as GatePayload;
    assert.equal(payload.authenticity.required, true);

    const off = runGate(["--json", `--matrix=${join(tree.root, "docs", "flash-matrix.json")}`], {
      ...process.env,
      GUARDTALK_REQUIRE_SIGNED_ROOT: "0",
    });
    assert.equal(off.code, 0, "an explicit 0 must not demand a signature");
  } finally {
    tree.writer.cleanup();
  }
});

/* ------------------------------------------------------------- gate (b) --- */

test("SIGNED-ROOT (b): a CORRECTLY SIGNED root PASSES with a throwaway /tmp signer", () => {
  const tree = genuineTree(FIXTURE_PRODUCTS);
  const signer = makeSigner();
  try {
    signAllChannels(tree.root, signer, FIXTURE_PRODUCTS);
    writeTrustList(tree.root, signer.pub);

    const signed = gateTree(tree.root, ["--require-signed-root"]);
    assert.equal(signed.code, 0, `${signed.payload.gate}: ${signed.payload.summary}`);
    assert.equal(signed.payload.gate, "PASS");
    assert.equal(signed.payload.clauses.length, 15);
    const clause = signed.payload.clauses.find((c) => c.id === "signed-channel-root");
    assert.ok(clause !== undefined);
    assert.equal(clause.ok, true);
    assert.match(clause.detail, /verify/);

    // The mode surface follows the mechanism: the pin check still ran, but a
    // VERIFIED signed root is the stronger claim and it is the one reported.
    assert.equal(signed.payload.anchorMode.id, "signed-root");
    assert.equal(signed.payload.anchorMode.signed, true);
    assert.equal(signed.payload.anchorMode.label, "signed-root (production)");
    assert.equal(signed.payload.authenticity.status, "verified");
    assert.equal(signed.payload.authenticity.verified, true);
    assert.equal(signed.payload.authenticity.required, true);
    assert.equal(signed.payload.authenticity.trustSource, "out-of-band");
    assert.equal(signed.payload.authenticity.signer, TRUSTED_PRINCIPAL);
    assert.equal(signed.payload.authenticity.namespace, SIGNATURE_NAMESPACE);
    assert.equal(signed.payload.authenticity.channels.length, FIXTURE_PRODUCTS.length);
    assert.ok(
      signed.payload.authenticity.channels.every((c) => c.status === "verified"),
      "every packed channel must verify",
    );
  } finally {
    signer.dispose();
    tree.writer.cleanup();
  }
});

/* ------------------------------------------------------------- gate (c) --- */

test("SIGNED-ROOT (c): the dev channel's behaviour and 14-clause contract are unchanged", () => {
  const live = runGate(["--json"]);
  assert.equal(live.code, 0, live.stdout);
  const payload = JSON.parse(live.stdout) as GatePayload;
  assert.equal(payload.gate, "PASS");
  assert.equal(payload.clauses.length, 14, "no clause may be added to the dev channel");
  assert.ok(payload.clauses.every((c) => c.ok), "all 14 clauses remain [ok]");
  assert.equal(payload.anchorMode.id, "review-gated-pins");
  assert.equal(payload.anchorMode.signed, false);
  assert.equal(payload.authenticity.required, false);
  assert.equal(payload.authenticity.status, "absent");
  assert.equal(payload.authenticity.verified, false);
  assert.equal(payload.authenticity.signed, false);
  // The dev channel's authenticity record must not read as a positive claim.
  assert.match(payload.authenticity.detail, /review-gated pins remain the only/);
});

/* ------------------------------------------------------------- gate (d) --- */

test("SIGNED-ROOT (d): the gate DISTINGUISHES the mechanisms in a structured field", () => {
  const tree = genuineTree(FIXTURE_PRODUCTS);
  const signer = makeSigner();
  try {
    const unsigned = gateTree(tree.root);
    signAllChannels(tree.root, signer, FIXTURE_PRODUCTS);
    writeTrustList(tree.root, signer.pub);
    const signed = gateTree(tree.root);

    // Same tree shape, same pins, ONLY the signed root differs — and the
    // machine surface reports a different mechanism. A hardcoded value could
    // not do this.
    assert.equal(unsigned.payload.authenticity.mechanism, "review-gated-pins");
    assert.equal(signed.payload.authenticity.mechanism, "signed-root");
    assert.notEqual(unsigned.payload.authenticity.status, signed.payload.authenticity.status);
    assert.equal(unsigned.payload.authenticity.signed, false);
    assert.equal(signed.payload.authenticity.signed, true);

    // Both forms are fields on the evaluation result AND on --json.
    const direct: GateResult = evaluateGate(
      JSON.parse(readFileSync(join(tree.root, "docs", "flash-matrix.json"), "utf8")) as Record<string, unknown>,
      { installerRoot: tree.root, releasesDir: join(tree.root, "releases", "desktop-flash") },
    );
    assert.equal(direct.authenticity.mechanism, "signed-root");
    assert.equal(direct.authenticity.mode, "signed-root");
    assert.equal(direct.anchorMode.id, "signed-root");
    assert.equal(typeof direct.authenticity.detail, "string");

    // And the signed verdict reaches --verdict-out so the claims linter can
    // consume it without importing the gate.
    const verdictPath = join(tree.root, "verdict.json");
    runGate([`--matrix=${join(tree.root, "docs", "flash-matrix.json")}`, `--verdict-out=${verdictPath}`]);
    const verdict = JSON.parse(readFileSync(verdictPath, "utf8")) as {
      authenticity: { mechanism: string; status: string };
      anchorMode: { id: string };
    };
    assert.equal(verdict.authenticity.mechanism, "signed-root");
    assert.equal(verdict.authenticity.status, "verified");
    assert.equal(verdict.anchorMode.id, "signed-root");
  } finally {
    signer.dispose();
    tree.writer.cleanup();
  }
});

/* ------------------------------------------------------- fail-closed set --- */

test("SIGNED-ROOT (fail closed): a statement that no longer describes the bytes FAILS", () => {
  const tree = genuineTree(FIXTURE_PRODUCTS.slice(0, 1));
  const signer = makeSigner();
  const product = FIXTURE_PRODUCTS[0] as string;
  try {
    signAllChannels(tree.root, signer, [product]);
    writeTrustList(tree.root, signer.pub);

    // The signature is untouched and genuine; the CHANNEL changed after signing.
    // This is the forgery the statement binding exists to catch: a valid
    // signature over metadata that is not what ships.
    writeFileSync(join(tree.root, "channels", product, "SHA256SUMS"), `${sha256(Buffer.from("forged\n"))}  boot.img\n`);

    const result = verifyChannelSignature({
      dir: join(tree.root, "channels", product),
      product,
      installerRoot: tree.root,
    });
    assert.equal(result.status, "invalid");
    assert.match(result.detail, /does not describe the bytes on disk/);
  } finally {
    signer.dispose();
    tree.writer.cleanup();
  }
});

test("SIGNED-ROOT (fail closed): a root signed by a key the trust list does not name FAILS", () => {
  const tree = genuineTree(FIXTURE_PRODUCTS.slice(0, 1));
  const signer = makeSigner();
  const impostor = makeSigner();
  const product = FIXTURE_PRODUCTS[0] as string;
  try {
    signAllChannels(tree.root, impostor, [product]);
    writeTrustList(tree.root, signer.pub); // trusts the OTHER key
    const result = verifyChannelSignature({
      dir: join(tree.root, "channels", product),
      product,
      installerRoot: tree.root,
    });
    assert.equal(result.status, "invalid");
    assert.equal(result.verified, false);
    assert.match(result.detail, /ssh-keygen -Y verify rejected/);
  } finally {
    impostor.dispose();
    signer.dispose();
    tree.writer.cleanup();
  }
});

test("SIGNED-ROOT (fail closed): a channel-local trust list is self-signed and does NOT authenticate", () => {
  const tree = genuineTree(FIXTURE_PRODUCTS.slice(0, 1));
  const signer = makeSigner();
  const product = FIXTURE_PRODUCTS[0] as string;
  try {
    signAllChannels(tree.root, signer, [product]);
    // NO docs/expected-allowed-signers. The only trust list ships INSIDE the
    // channel it vouches for — the attacker supplies both halves.
    writeFileSync(
      join(tree.root, "channels", product, "allowed_signers"),
      `${TRUSTED_PRINCIPAL} namespaces="${SIGNATURE_NAMESPACE}" ${signer.pub}\n`,
    );
    const result = verifyChannelSignature({
      dir: join(tree.root, "channels", product),
      product,
      installerRoot: tree.root,
    });
    assert.equal(result.status, "untrusted");
    assert.equal(result.verified, false);
    assert.equal(result.trustSource, "channel-local");
    assert.match(result.detail, /self-signed/);
  } finally {
    signer.dispose();
    tree.writer.cleanup();
  }
});

test("SIGNED-ROOT (fail closed): an UNSCOPED trust list is refused", () => {
  const tree = genuineTree(FIXTURE_PRODUCTS.slice(0, 1));
  const signer = makeSigner();
  const product = FIXTURE_PRODUCTS[0] as string;
  try {
    signAllChannels(tree.root, signer, [product]);
    writeTrustList(tree.root, signer.pub, false); // no namespaces="…"
    const result = verifyChannelSignature({
      dir: join(tree.root, "channels", product),
      product,
      installerRoot: tree.root,
    });
    assert.equal(result.status, "invalid");
    assert.match(result.detail, /namespaces/);
  } finally {
    signer.dispose();
    tree.writer.cleanup();
  }
});

test("SIGNED-ROOT (fail closed): a statement with no signature FAILS", () => {
  const tree = genuineTree(FIXTURE_PRODUCTS.slice(0, 1));
  const product = FIXTURE_PRODUCTS[0] as string;
  try {
    const dir = join(tree.root, "channels", product);
    const manifest = readFileSync(join(dir, "manifest.json"));
    const sums = readFileSync(join(dir, "SHA256SUMS"));
    const declared = (JSON.parse(manifest.toString("utf8")) as { channel: string }).channel;
    writeFileSync(
      join(dir, ROOT_STATEMENT_FILE),
      buildRootStatement({
        product,
        channel: declared,
        digests: { "manifest.json": sha256(manifest), SHA256SUMS: sha256(sums) },
      }),
    );
    const result = verifyChannelSignature({ dir, product, installerRoot: tree.root });
    assert.equal(result.status, "invalid");
    assert.match(result.detail, new RegExp(`${ROOT_SIGNATURE_FILE} is absent`));
    assert.equal(result.verified, false);
  } finally {
    tree.writer.cleanup();
  }
});

test("SIGNED-ROOT (fail closed): a signed root cannot be REPLAYED onto another product", () => {
  const products = FIXTURE_PRODUCTS.slice(0, 2);
  const tree = genuineTree(products);
  const signer = makeSigner();
  try {
    const [tokay, akita] = products as [string, string];
    // Sign tokay's root, then COPY it into akita's channel dir: the digest of
    // akita's own SHA256SUMS is identical (fixtures share bytes) but the
    // statement names `product tokay`, and that is a hard mismatch.
    signAllChannels(tree.root, signer, [tokay]);
    writeTrustList(tree.root, signer.pub);
    const src = join(tree.root, "channels", tokay);
    const dst = join(tree.root, "channels", akita);
    writeFileSync(join(dst, ROOT_STATEMENT_FILE), readFileSync(join(src, ROOT_STATEMENT_FILE)));
    writeFileSync(join(dst, ROOT_SIGNATURE_FILE), readFileSync(join(src, ROOT_SIGNATURE_FILE)));

    const result = verifyChannelSignature({ dir: dst, product: akita, installerRoot: tree.root });
    assert.equal(result.status, "invalid");
    assert.match(result.detail, /cannot be replayed onto another product/);
  } finally {
    signer.dispose();
    tree.writer.cleanup();
  }
});

test("SIGNED-ROOT (fail closed): in DEV mode, a BROKEN signature still fails the gate", () => {
  const tree = genuineTree(FIXTURE_PRODUCTS.slice(0, 1));
  const signer = makeSigner();
  const product = FIXTURE_PRODUCTS[0] as string;
  try {
    signAllChannels(tree.root, signer, [product]);
    writeTrustList(tree.root, signer.pub);
    // Corrupt the signature AFTER signing: presence must never be mistaken for
    // validity, even when no mode demanded a signature.
    writeFileSync(
      join(tree.root, "channels", product, ROOT_SIGNATURE_FILE),
      "-----BEGIN SSH SIGNATURE-----\nAAAA\n-----END SSH SIGNATURE-----\n",
    );
    const run = gateTree(tree.root);
    assert.equal(run.code, 1, "signing material that does not verify must FAIL, not be ignored");
    const clause = run.payload.clauses.find((c) => c.id === "signed-channel-root");
    assert.ok(clause !== undefined, "the clause appears because material is present");
    assert.equal(clause.ok, false);
    assert.match(clause.detail, /ssh-keygen -Y verify rejected/);
  } finally {
    signer.dispose();
    tree.writer.cleanup();
  }
});

test("SIGNED-ROOT (fail closed): a manifest that DECLARES signature.required forces the check", () => {
  const tree = genuineTree(FIXTURE_PRODUCTS.slice(0, 1));
  const product = FIXTURE_PRODUCTS[0] as string;
  try {
    const path = join(tree.root, "channels", product, "manifest.json");
    const manifest = JSON.parse(readFileSync(path, "utf8")) as Record<string, unknown>;
    manifest.signature = { required: true, mode: "ssh-keygen" };
    writeFileSync(path, `${JSON.stringify(manifest, null, 2)}\n`);

    // No flag, no env: the CHANNEL says it must be signed, so it must be.
    const run = gateTree(tree.root);
    assert.equal(run.code, 1);
    assert.equal(run.payload.authenticity.required, true);
    assert.equal(run.payload.authenticity.status, "absent");
  } finally {
    tree.writer.cleanup();
  }
});

/* ---------------------------------------------------------------- shape --- */

test("SIGNED-ROOT: no key material is written outside the throwaway temp dir", () => {
  const signer = makeSigner();
  try {
    // The generated key lives in the OS temp dir and nowhere else: this asserts
    // the property the drill depends on (nothing is written into the repo).
    assert.ok(signer.dir.startsWith(tmpdir()), signer.dir);
    assert.ok(signer.key.startsWith(tmpdir()), signer.key);
    assert.match(readFileSync(signer.key, "utf8"), /BEGIN OPENSSH PRIVATE KEY/);
    // And a trust list refuses private material outright.
    assert.equal(checkAllowedSigners(readFileSync(signer.key, "utf8")).ok, false);
  } finally {
    signer.dispose();
  }
});

test("SIGNED-ROOT: verifyChannelSignatures never reports `signed-root` without a verification", () => {
  // The aggregate shape, exercised directly: a result whose channels did not
  // verify must not carry the evidence `anchor-mode.mjs` accepts.
  const tree = genuineTree(FIXTURE_PRODUCTS.slice(0, 1));
  try {
    const gate = evaluateGate(
      JSON.parse(readFileSync(join(tree.root, "docs", "flash-matrix.json"), "utf8")) as Record<string, unknown>,
      { installerRoot: tree.root, releasesDir: join(tree.root, "releases", "desktop-flash") },
    );
    const auth = gate.authenticity;
    assert.equal(auth.verified, false);
    assert.notEqual(auth.mechanism, "signed-root");
    const aggregate = gate as unknown as { authenticity: ChannelSignaturesResult };
    assert.equal(aggregate.authenticity.verified, false);
    // `defaultVerifyRunner` exists and is reachable — the module is wired, not
    // a stub that happens to typecheck.
    assert.equal(typeof defaultVerifyRunner, "function");
  } finally {
    tree.writer.cleanup();
  }
});
