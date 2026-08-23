/**
 * One RSA-4096 user key + a minimal SHA256_RSA4096 vbmeta signed by it.
 * Cached per process so late/update suites share the generation cost.
 */
import { beBytesToBigInt } from "../../lib/avb/bytes.js";
import { encodePkmd } from "../../lib/avb/pkmd.js";
import { resignVbmetaWithRelease } from "../../lib/avb/signer.js";
import { AlgorithmType } from "../../lib/avb/parser.js";

export interface SignedAnchor {
  readonly pkmd: Uint8Array;
  readonly vbmeta: Uint8Array;
}

const AUTH_SIZE = 576;
const PKMD_SIZE = 1032;
const AUX_SIZE = 1088;

let cached: Promise<SignedAnchor> | undefined;

export function signedAnchor(): Promise<SignedAnchor> {
  cached ??= buildSignedAnchor();
  return cached;
}

async function buildSignedAnchor(): Promise<SignedAnchor> {
  const pair = await crypto.subtle.generateKey(
    {
      name: "RSASSA-PKCS1-v1_5",
      modulusLength: 4096,
      publicExponent: new Uint8Array([1, 0, 1]),
      hash: "SHA-256",
    },
    true,
    ["sign", "verify"],
  );
  const jwk = (await crypto.subtle.exportKey("jwk", pair.publicKey)) as JsonWebKey & {
    n: string;
    e: string;
  };
  const pkmd = encodePkmd({
    n: beBytesToBigInt(fromBase64Url(jwk.n)),
    e: beBytesToBigInt(fromBase64Url(jwk.e)),
  });
  const header = new Uint8Array(256);
  const view = new DataView(header.buffer);
  header.set([0x41, 0x56, 0x42, 0x30], 0); // AVB0
  view.setUint32(4, 1, false);
  view.setUint32(8, 0, false);
  view.setBigUint64(12, BigInt(AUTH_SIZE), false);
  view.setBigUint64(20, BigInt(AUX_SIZE), false);
  view.setUint32(28, AlgorithmType.SHA256_RSA4096, false);
  view.setBigUint64(32, 0n, false); // hash_offset
  view.setBigUint64(40, 32n, false);
  view.setBigUint64(48, 32n, false); // signature_offset
  view.setBigUint64(56, 512n, false);
  view.setBigUint64(64, 0n, false); // public_key_offset
  view.setBigUint64(72, BigInt(PKMD_SIZE), false);
  view.setBigUint64(80, BigInt(PKMD_SIZE), false);
  view.setBigUint64(88, 0n, false);
  view.setBigUint64(96, 0n, false);
  view.setBigUint64(104, 0n, false);
  const release = new TextEncoder().encode("test-anchor");
  header.set(release, 128);

  const blob = new Uint8Array(256 + AUTH_SIZE + AUX_SIZE);
  blob.set(header, 0);
  blob.set(pkmd, 256 + AUTH_SIZE);
  const vbmeta = await resignVbmetaWithRelease(blob, pair.privateKey, "test-anchor");
  return { pkmd, vbmeta };
}

function fromBase64Url(b64: string): Uint8Array {
  const alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";
  const out: number[] = [];
  let bits = 0;
  let acc = 0;
  for (const ch of b64) {
    const v = alphabet.indexOf(ch);
    if (v < 0) {
      continue;
    }
    acc = (acc << 6) | v;
    bits += 6;
    if (bits >= 8) {
      bits -= 8;
      out.push((acc >> bits) & 0xff);
    }
  }
  return new Uint8Array(out);
}
