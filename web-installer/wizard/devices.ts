import type { AllowedProduct } from "../src/types.js";

export interface WizardDevice {
  id: AllowedProduct;
  label: string;
}

/** Advertised picker. tokay + akita (Pixel 8a). Rango / shiba / husky are not offered. */
export const WIZARD_DEVICES: readonly WizardDevice[] = [
  { id: "tokay", label: "Pixel 9 (tokay)" },
  { id: "akita", label: "Pixel 8a (akita)" },
];

export function isOfferedDevice(id: string): id is AllowedProduct {
  return WIZARD_DEVICES.some((device) => device.id === id);
}
