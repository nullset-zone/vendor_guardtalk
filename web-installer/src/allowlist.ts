import { ChannelError, WrongProductError } from "./errors.js";
import {
  ALLOWED_PRODUCTS,
  type AllowedProduct,
  type ChannelManifest,
} from "./types.js";

/** tokay (Pixel 9), akita (Pixel 8a), komodo (Pixel 9 Pro XL), rango (Pixel 10 Pro Fold, experimental / boot HOLD). Unstamped shiba / husky / caiman / tegu / comet stay rejected (DEC-WEBINSTALL-015). */
export function isAllowedProduct(product: string): product is AllowedProduct {
  return (ALLOWED_PRODUCTS as readonly string[]).includes(product.trim());
}

export function assertAllowedProduct(
  product: string,
): asserts product is AllowedProduct {
  const trimmed = product.trim();
  if (!isAllowedProduct(trimmed)) {
    throw new WrongProductError(trimmed === "" ? "(empty)" : trimmed);
  }
}

export function assertManifestAllowlist(manifest: ChannelManifest): void {
  assertAllowedProduct(manifest.product);
  if (manifest.advertisedDevices.length < 1) {
    throw new ChannelError("advertisedDevices must list at least the channel product");
  }
  for (const advertised of manifest.advertisedDevices) {
    assertAllowedProduct(advertised);
  }
  if (!manifest.advertisedDevices.includes(manifest.product)) {
    throw new ChannelError("advertisedDevices must include manifest.product");
  }
  for (const reserved of manifest.reservedProducts ?? []) {
    if (isAllowedProduct(reserved)) {
      throw new ChannelError("reservedProducts must not include an advertised device");
    }
  }
}
