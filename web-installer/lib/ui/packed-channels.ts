/**
 * GENERATED FILE — DO NOT EDIT BY HAND.
 *
 * Regenerate with: node scripts/gen-packed-channels.mjs
 * Drift check:     node scripts/gen-packed-channels.mjs --check
 *
 * Source of truth: the packed channel tree `channels/<product>/` plus the
 * advertised allowlist `src/types.ts` ALLOWED_PRODUCTS. This module exists so
 * the OFFLINE browser picker (CSP connect-src 'none', D-006) can offer exactly
 * the products that have a packed channel, without reading channels/ at runtime.
 *
 * HONESTY: BOOT_VERIFIED=false. PACKED means a channel exists on disk; it does
 * NOT mean the image boots and it is NOT a live-flash claim. The picker gate
 * fails closed: a product absent from this list, or present with packed:false,
 * is not selectable.
 */

export interface PackedChannelEntry {
  readonly product: string;
  readonly packed: boolean;
  readonly sourceStamp: string | null;
  readonly channelLabel: string | null;
  readonly artifactCount: number;
}

export const PACKED_CHANNELS: readonly PackedChannelEntry[] = [
  {
    product: "tokay",
    packed: true,
    sourceStamp: "tokay-20261114-095740",
    channelLabel: "dev/unlocked",
    artifactCount: 24,
  },
  {
    product: "akita",
    packed: true,
    sourceStamp: "akita-20261114-100809",
    channelLabel: "dev/unlocked",
    artifactCount: 24,
  },
  {
    product: "komodo",
    packed: true,
    sourceStamp: "komodo-20261114-093819",
    channelLabel: "dev/unlocked",
    artifactCount: 24,
  },
  {
    product: "rango",
    packed: true,
    sourceStamp: "rango-20261114-091159",
    channelLabel: "dev/unlocked",
    artifactCount: 25,
  },
  {
    product: "blazer",
    packed: true,
    sourceStamp: "blazer-20261114-092102",
    channelLabel: "dev/unlocked",
    artifactCount: 25,
  },
  {
    product: "caiman",
    packed: true,
    sourceStamp: "caiman-20261114-084610",
    channelLabel: "dev/unlocked",
    artifactCount: 24,
  },
  {
    product: "frankel",
    packed: true,
    sourceStamp: "frankel-20261114-090341",
    channelLabel: "dev/unlocked",
    artifactCount: 25,
  },
  {
    product: "stallion",
    packed: true,
    sourceStamp: "stallion-20261114-094654",
    channelLabel: "dev/unlocked",
    artifactCount: 24,
  },
];

/** The products with a packed channel on disk, derived from the list above. */
export const PACKED_PRODUCTS: readonly string[] = PACKED_CHANNELS.filter((c) => c.packed).map(
  (c) => c.product,
);

/** The packed-channel row for a product, or undefined when it is not advertised. */
export function packedChannel(product: string): PackedChannelEntry | undefined {
  return PACKED_CHANNELS.find((c) => c.product === product);
}

/** Whether a product has a packed channel. Absence is NOT packed (fail closed). */
export function hasPackedChannel(product: string): boolean {
  return packedChannel(product)?.packed === true;
}
