import type { AllowedProduct } from "../src/types.js";
import {
  DEFAULT_OFFERED_PRODUCT,
  WIZARD_DEVICES,
  deviceFromSearch,
  isOfferedDevice as isOfferedProductId,
  offeredProductIds,
  parseOfferedDevice,
  statusChipWord,
  type OfferedDeviceStatus,
  type OfferedProduct,
  type WizardDevice,
} from "../lib/ui/offered-devices.js";

export {
  DEFAULT_OFFERED_PRODUCT,
  WIZARD_DEVICES,
  deviceFromSearch,
  offeredProductIds,
  parseOfferedDevice,
  statusChipWord,
  type OfferedDeviceStatus,
  type WizardDevice,
};

/** Picker membership; advertised ids match AllowedProduct after DEC-WEBINSTALL-015. */
export function isOfferedDevice(id: string): id is AllowedProduct {
  return isOfferedProductId(id);
}

export type { OfferedProduct };
