import { STAGED_PRODUCTS, type StagedProduct } from "../src/allowlist.js";
import { LIVE_FLASH_CLAIMED, type BootChainMode } from "../src/types.js";

export type OfferedDeviceStatus = "supported" | "experimental";
export type StatusJsonFact = "target" | "experimental";

export interface WizardDevice {
  readonly id: StagedProduct;
  /** Marketing name shown in the picker and readiness badge (e.g. Pixel 9). */
  readonly deviceName: string;
  /** Picker option text. Experimental devices name HOLD in the label. */
  readonly label: string;
  readonly status: OfferedDeviceStatus;
  readonly statusJsonFact: StatusJsonFact;
  readonly defaultBootChain: BootChainMode;
  readonly supportedBootChains: readonly BootChainMode[];
  readonly superMode: "super" | "super_empty";
  readonly readinessBadge: string;
}

export const WIZARD_DEVICES: readonly WizardDevice[] = [
  {
    id: "tokay",
    deviceName: "Pixel 9",
    label: "Pixel 9 (tokay)",
    status: "supported",
    statusJsonFact: "target",
    defaultBootChain: "gt",
    supportedBootChains: ["gt"],
    superMode: "super_empty",
    readinessBadge: "TARGET · dev/unlocked · gt · LIVE_FLASH_CLAIMED=false",
  },
  {
    id: "komodo",
    deviceName: "Pixel 9 Pro XL",
    label: "Pixel 9 Pro XL (komodo)",
    status: "supported",
    statusJsonFact: "target",
    defaultBootChain: "gt",
    supportedBootChains: ["gt"],
    superMode: "super_empty",
    readinessBadge: "TARGET · dev/unlocked · gt · LIVE_FLASH_CLAIMED=false",
  },
  {
    id: "caiman",
    deviceName: "Pixel 9 Pro",
    label: "Pixel 9 Pro (caiman)",
    status: "supported",
    statusJsonFact: "target",
    defaultBootChain: "gt",
    supportedBootChains: ["gt"],
    superMode: "super_empty",
    readinessBadge: "TARGET · dev/unlocked · gt · LIVE_FLASH_CLAIMED=false",
  },
  {
    id: "frankel",
    deviceName: "Pixel 10",
    label: "Pixel 10 (frankel) [hybrid rescue-boot]",
    status: "supported",
    statusJsonFact: "target",
    defaultBootChain: "hybrid",
    supportedBootChains: ["gt", "hybrid"],
    superMode: "super",
    readinessBadge: "TARGET · dev/unlocked · hybrid rescue-boot · LIVE_FLASH_CLAIMED=false",
  },
  {
    id: "stallion",
    deviceName: "Pixel 9a",
    label: "Pixel 9a (stallion)",
    status: "supported",
    statusJsonFact: "target",
    defaultBootChain: "gt",
    supportedBootChains: ["gt"],
    superMode: "super_empty",
    readinessBadge: "TARGET · dev/unlocked · gt · LIVE_FLASH_CLAIMED=false",
  },
  {
    id: "blazer",
    deviceName: "Pixel 10 Pro",
    label: "Pixel 10 Pro (blazer) [hybrid rescue-boot]",
    status: "supported",
    statusJsonFact: "target",
    defaultBootChain: "hybrid",
    supportedBootChains: ["gt", "hybrid"],
    superMode: "super",
    readinessBadge: "TARGET · dev/unlocked · hybrid rescue-boot · LIVE_FLASH_CLAIMED=false",
  },
  {
    id: "rango",
    deviceName: "Pixel 10 Pro Fold",
    label: "Pixel 10 Pro Fold (rango) — experimental / boot HOLD",
    status: "experimental",
    statusJsonFact: "target",
    defaultBootChain: "hybrid",
    supportedBootChains: ["gt", "hybrid"],
    superMode: "super",
    readinessBadge: "EXPERIMENTAL · boot HOLD · hybrid rescue-boot · LIVE_FLASH_CLAIMED=false",
  },
  {
    id: "akita",
    deviceName: "Pixel 8a",
    label: "Pixel 8a (akita) — experimental",
    status: "experimental",
    statusJsonFact: "experimental",
    defaultBootChain: "gt",
    supportedBootChains: ["gt"],
    superMode: "super_empty",
    readinessBadge: "EXPERIMENTAL · dev/unlocked · gt · LIVE_FLASH_CLAIMED=false",
  },
];

export type OfferedProduct = StagedProduct;

export const DEFAULT_OFFERED_PRODUCT: OfferedProduct = WIZARD_DEVICES[0]?.id ?? "tokay";

export { LIVE_FLASH_CLAIMED };

export function offeredProductIds(): readonly OfferedProduct[] {
  return WIZARD_DEVICES.map((d) => d.id);
}

/** Picker membership: all 8 packed devices in STAGED_PRODUCTS. */
export function isOfferedDevice(id: string): id is OfferedProduct {
  const trimmed = id.trim();
  return (STAGED_PRODUCTS as readonly string[]).includes(trimmed) &&
    WIZARD_DEVICES.some((d) => d.id === trimmed);
}

export function getWizardDevice(id: string): WizardDevice | undefined {
  const trimmed = id.trim();
  return WIZARD_DEVICES.find((d) => d.id === trimmed);
}

export function parseOfferedDevice(raw: string | null | undefined): OfferedProduct | null {
  if (typeof raw !== "string") {
    return null;
  }
  const trimmed = raw.trim();
  return isOfferedDevice(trimmed) ? trimmed : null;
}

export function deviceFromSearch(search: string | URLSearchParams): OfferedProduct {
  const params = typeof search === "string" ? new URLSearchParams(search) : search;
  return parseOfferedDevice(params.get("device")) ?? DEFAULT_OFFERED_PRODUCT;
}

export function statusChipWord(status: OfferedDeviceStatus): string {
  return status === "experimental" ? "EXPERIMENTAL" : "SUPPORTED";
}
