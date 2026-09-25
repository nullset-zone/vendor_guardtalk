/**
 * Shared advertised-device labels for the wizard picker and `/install`
 * (DEC-WEBINSTALL-015). Rango is selectable as experimental / boot HOLD —
 * not production-boot-green. Unstamped shiba / husky / caiman are not offered.
 *
 * Lives under lib/ui so route dist (build-site.sh copies lib/) can import it.
 * wizard/devices.ts re-exports this module.
 *
 * DEC-010: listing komodo is not a signed-user FLASH_READY claim for
 * `komodo-20260915-063833`.
 */

/** Current advertised komodo stamp is userdebug/test-keys, not FLASH_READY. */
export const KOMODO_STAMP_HONESTY =
  "The current komodo stamp komodo-20260915-063833 is userdebug/test-keys, not a signed user FLASH_READY image. LIVE_FLASH_CLAIMED=false.";

export type OfferedDeviceStatus = "supported" | "experimental";

export interface WizardDevice {
  readonly id: "tokay" | "akita" | "komodo" | "rango";
  /** Marketing name shown in the /install table (e.g. Pixel 9). */
  readonly deviceName: string;
  /** Picker option text. Experimental devices name HOLD in the label. */
  readonly label: string;
  readonly status: OfferedDeviceStatus;
}

export const WIZARD_DEVICES: readonly WizardDevice[] = [
  { id: "tokay", deviceName: "Pixel 9", label: "Pixel 9 (tokay)", status: "supported" },
  { id: "akita", deviceName: "Pixel 8a", label: "Pixel 8a (akita)", status: "supported" },
  { id: "komodo", deviceName: "Pixel 9 Pro XL", label: "Pixel 9 Pro XL (komodo)", status: "supported" },
  {
    id: "rango",
    deviceName: "Pixel 10 Pro Fold",
    label: "Pixel 10 Pro Fold (rango) — experimental / boot HOLD",
    status: "experimental",
  },
];

export type OfferedProduct = (typeof WIZARD_DEVICES)[number]["id"];

export const DEFAULT_OFFERED_PRODUCT: OfferedProduct = WIZARD_DEVICES[0]?.id ?? "tokay";

export function isOfferedDevice(id: string): id is OfferedProduct {
  return WIZARD_DEVICES.some((device) => device.id === id);
}

export function parseOfferedDevice(raw: string | null | undefined): OfferedProduct | undefined {
  if (raw === undefined || raw === null) {
    return undefined;
  }
  const trimmed = raw.trim();
  return isOfferedDevice(trimmed) ? trimmed : undefined;
}

/** `?device=` from the query string; unknown/missing values fall back to tokay. */
export function deviceFromSearch(search: string | URLSearchParams): OfferedProduct {
  const raw = search instanceof URLSearchParams ? search.toString() : search;
  const params = new URLSearchParams(raw.startsWith("?") ? raw.slice(1) : raw);
  return parseOfferedDevice(params.get("device")) ?? DEFAULT_OFFERED_PRODUCT;
}

export function offeredProductIds(): readonly OfferedProduct[] {
  return WIZARD_DEVICES.map((device) => device.id);
}

export function statusChipWord(status: OfferedDeviceStatus): string {
  return status === "supported" ? "SUPPORTED" : "EXPERIMENTAL · BOOT HOLD";
}
