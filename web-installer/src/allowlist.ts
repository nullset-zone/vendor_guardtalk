import { ChannelError, WrongProductError } from "./errors.js";
import {
  ALLOWED_PRODUCTS,
  type AllowedProduct,
  type ChannelManifest,
} from "./types.js";

/** tokay (Pixel 9) and akita (Pixel 8a). Rango and shiba/husky stay rejected (DEC-001/010). */
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
    if (reserved === "rango") {
      throw new ChannelError("rango must not appear in reservedProducts");
    }
    if (isAllowedProduct(reserved)) {
      throw new ChannelError("reservedProducts must not include an advertised device");
    }
  }
}
