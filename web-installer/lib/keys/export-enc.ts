/**
 * Encrypted key export/import (opt-in persistence path).
 *
 * // confirm KDF availability; PBKDF2 fallback per Q-09 — Argon2id is not
 * available via WebCrypto natively; PBKDF2-SHA256 with >=600_000 iterations
 * ships instead and is labelled as such in the UI.
 *
 * Format (armored PEM-like, no network ever sees this — D-007):
 *   -----BEGIN GUARDTALK ENCRYPTED KEY-----
 *   Version: GTKEY-1
 *   KDF: PBKDF2-SHA256
 *   Iterations: 600000
 *   Salt: <base64 16B>
 *   IV: <base64 12B>
 *   (blank line)
 *   <base64 AES-256-GCM(ciphertext||tag), wrapped at 64 chars>
 *   -----END GUARDTALK ENCRYPTED KEY-----
 *
 * Plaintext inside the envelope is the raw key DER bundle (PKCS#8 for RSA).
 * A wrong passphrase fails as a clean KeyExportError; error strings never
 * contain material, passphrases, or decrypted bytes.
 */
import { zeroise } from "./zeroise.js";

const ITERATIONS_MIN = 600_000;
/** Length floor only — no strength theater (lens-1 F-MED-4). */
export const PASSPHRASE_MIN_LENGTH = 12;
const SALT_BYTES = 16;
const IV_BYTES = 12;
const ARMOR_BEGIN = "-----BEGIN GUARDTALK ENCRYPTED KEY-----";
const ARMOR_END = "-----END GUARDTALK ENCRYPTED KEY-----";

/** Transient private material owned by the caller; scrub when done. */
export interface KeyMaterial {
  /** PKCS#8 DER encoding of the private key (RSA). */
  der: Uint8Array;
}

export class KeyExportError extends Error {
  constructor(message: string) {
    super(message);
    this.name = this.constructor.name;
  }
}

const cryptoRef: Crypto = globalThis.crypto;

async function deriveWrappingKey(
  passphrase: string,
  salt: Uint8Array,
  iterations: number,
): Promise<CryptoKey> {
  const encoded = new TextEncoder().encode(passphrase);
  try {
    const base = await cryptoRef.subtle.importKey("raw", encoded, "PBKDF2", false, [
      "deriveKey",
    ]);
    return await cryptoRef.subtle.deriveKey(
      { name: "PBKDF2", hash: "SHA-256", salt: salt as BufferSource, iterations },
      base,
      { name: "AES-GCM", length: 256 },
      false,
      ["encrypt", "decrypt"],
    );
  } finally {
    // The encoded passphrase copy is transient; best-effort zero it.
    zeroise(encoded);
  }
}

/** Encrypt a DER bundle into armored PEM-like text. */
export async function exportEncryptedPem(
  material: KeyMaterial,
  passphrase: string,
  options: { iterations?: number } = {},
): Promise<string> {
  if (passphrase.length < PASSPHRASE_MIN_LENGTH) {
    throw new KeyExportError(
      `passphrase must be at least ${String(PASSPHRASE_MIN_LENGTH)} characters`,
    );
  }
  const iterations = Math.max(options.iterations ?? ITERATIONS_MIN, ITERATIONS_MIN);
  const salt = cryptoRef.getRandomValues(new Uint8Array(SALT_BYTES));
  const iv = cryptoRef.getRandomValues(new Uint8Array(IV_BYTES));
  try {
    const key = await deriveWrappingKey(passphrase, salt, iterations);
    const sealed = await cryptoRef.subtle.encrypt(
      { name: "AES-GCM", iv: iv as BufferSource, tagLength: 128 },
      key,
      material.der as BufferSource,
    );
    return armor(salt, iv, iterations, new Uint8Array(sealed));
  } finally {
    // Zero local copies only AFTER the armor has captured them.
    zeroise(salt);
    zeroise(iv);
  }
}

/**
 * DecryptPath (symmetric): parse armored text, unwrap, return the DER bundle.
 * Throws KeyExportError on wrong passphrase / malformed armor. The returned
 * buffer is fresh memory owned by the caller — zeroise() after import.
 */
export async function decryptEncryptedPem(
  pemText: string,
  passphrase: string,
): Promise<KeyMaterial> {
  const parsed = parseArmored(pemText);
  const key = await deriveWrappingKey(passphrase, parsed.salt, parsed.iterations);
  let plain: ArrayBuffer;
  try {
    plain = await cryptoRef.subtle.decrypt(
      { name: "AES-GCM", iv: parsed.iv as BufferSource, tagLength: 128 },
      key,
      parsed.ciphertext as BufferSource,
    );
  } catch {
    throw new KeyExportError("wrong passphrase or corrupted file");
  }
  return { der: new Uint8Array(plain) };
}

function armor(
  salt: Uint8Array,
  iv: Uint8Array,
  iterations: number,
  ciphertext: Uint8Array,
): string {
  const body = base64Encode(ciphertext).replace(/(.{64})/g, "$1\n").trimEnd();
  return [
    ARMOR_BEGIN,
    "Version: GTKEY-1",
    "KDF: PBKDF2-SHA256",
    `Iterations: ${String(iterations)}`,
    `Salt: ${base64Encode(salt)}`,
    `IV: ${base64Encode(iv)}`,
    "",
    body,
    ARMOR_END,
    "",
  ].join("\n");
}

interface Armored {
  salt: Uint8Array;
  iv: Uint8Array;
  iterations: number;
  ciphertext: Uint8Array;
}

function parseArmored(text: string): Armored {
  if (!text.includes(ARMOR_BEGIN) || !text.includes(ARMOR_END)) {
    throw new KeyExportError("not a GuardTalk encrypted key file");
  }
  const header = text.slice(text.indexOf(ARMOR_BEGIN) + ARMOR_BEGIN.length, text.indexOf(ARMOR_END));
  const [metaBlock, ...bodyParts] = header.split("\n\n");
  if (metaBlock === undefined || bodyParts.length === 0) {
    throw new KeyExportError("malformed encrypted key armor");
  }
  const fields = new Map<string, string>();
  for (const line of metaBlock.split("\n")) {
    const idx = line.indexOf(":");
    if (idx > 0) {
      fields.set(line.slice(0, idx).trim(), line.slice(idx + 1).trim());
    }
  }
  const kdf = fields.get("KDF");
  if (kdf !== "PBKDF2-SHA256") {
    throw new KeyExportError(`unsupported KDF ${JSON.stringify(kdf ?? "")}`);
  }
  const iterations = Number.parseInt(fields.get("Iterations") ?? "", 10);
  const saltB64 = fields.get("Salt");
  const ivB64 = fields.get("IV");
  if (!Number.isFinite(iterations) || iterations < ITERATIONS_MIN) {
    throw new KeyExportError("iteration count below policy minimum");
  }
  if (saltB64 === undefined || ivB64 === undefined) {
    throw new KeyExportError("missing Salt or IV header");
  }
  const ciphertext = base64Decode(bodyParts.join("").replace(/\s+/g, ""));
  if (ciphertext.length === 0) {
    throw new KeyExportError("empty ciphertext body");
  }
  return {
    salt: base64Decode(saltB64),
    iv: base64Decode(ivB64),
    iterations,
    ciphertext,
  };
}

function base64Encode(bytes: Uint8Array): string {
  let binary = "";
  for (const b of bytes) {
    binary += String.fromCharCode(b);
  }
  return btoa(binary);
}

function base64Decode(value: string): Uint8Array {
  const binary = atob(value.replace(/-/g, "+").replace(/_/g, "/"));
  const out = new Uint8Array(binary.length);
  for (let i = 0; i < binary.length; i += 1) {
    out[i] = binary.charCodeAt(i);
  }
  return out;
}
