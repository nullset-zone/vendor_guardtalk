/**
 * Key generation (flow 1). RSA-4096 RSASSA-PKCS1-v1_5 SHA-256 via WebCrypto.
 * The private handle is non-extractable by construction (D-007): it can sign
 * and export its public half, never its private material.
 */

export const KEY_ALGORITHM: RsaHashedKeyGenParams = {
  name: "RSASSA-PKCS1-v1_5",
  modulusLength: 4096,
  publicExponent: new Uint8Array([0x01, 0x00, 0x01]),
  hash: "SHA-256",
};

export interface GeneratedKey {
  privateKey: CryptoKey;
  publicKey: CryptoKey;
}

const cryptoRef: Crypto = globalThis.crypto;

/** Generate a fresh key pair. Private side is extractable:false (D-007). */
export async function generateKey(): Promise<GeneratedKey> {
  const pair = await cryptoRef.subtle.generateKey(KEY_ALGORITHM, false, [
    "sign",
    "verify",
  ]);
  return {
    privateKey: pair.privateKey,
    publicKey: pair.publicKey,
  };
}

/**
 * Export the public half as a JWK (public material only — n, e, kty, alg).
 * The private fields are absent because the private handle is
 * non-extractable; this exports the public key object.
 */
export async function exportPublicJwk(publicKey: CryptoKey): Promise<JsonWebKey> {
  const jwk = await cryptoRef.subtle.exportKey("jwk", publicKey);
  delete jwk.d;
  delete jwk.p;
  delete jwk.q;
  delete jwk.dp;
  delete jwk.dq;
  delete jwk.qi;
  return jwk;
}
