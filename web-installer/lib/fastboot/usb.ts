/**
 * WebUsbFastbootTransport — WebUSB transport for fastboot.
 *
 * Hygiene mirrored from wizard/adb-usb.ts + adb-pipe.ts (READER-B §F):
 * class 255 / subclass 66 / protocol 1 filter, claim once, AbortSignal
 * forwarded into every transferIn, macrotask yield before close so aborted
 * transfers unwind, explicit DOMException classification (no swallowing).
 */
import { encodeCommand } from "./protocol.js";
import type { Transport } from "./client.js";

const FASTBOOT_CLASS = 255;
const FASTBOOT_SUBCLASS = 66;
const FASTBOOT_PROTOCOL = 1;
/** USB packet size for bulk reads (READER-B §E). */
export const PACKET_SIZE = 512;

export interface FastbootUsbDevice {
  configurations: UsbConfigSnap[];
  open(): Promise<void>;
  selectConfiguration(value: number): Promise<void>;
  claimInterface(value: number): Promise<void>;
  releaseInterface(value: number): Promise<void>;
  close(): Promise<void>;
  transferOut(endpoint: number, data: BufferSource): Promise<{ status: string }>;
  transferIn(
    endpoint: number,
    length: number,
    options?: { signal?: AbortSignal },
  ): Promise<{ status: string; data?: DataView }>;
}

export interface UsbPicker {
  requestDevice(options: {
    filters: { classCode: number; subclassCode: number; protocolCode: number }[];
  }): Promise<FastbootUsbDevice>;
}

export function browserUsbPicker(): UsbPicker | null {
  if (typeof navigator === "undefined") {
    return null;
  }
  const holder = navigator as Navigator & { usb?: UsbPicker };
  return holder.usb ?? null;
}

export class UsbFastbootError extends Error {
  constructor(message: string) {
    super(message);
    this.name = this.constructor.name;
  }
}

interface Endpoints {
  iface: number;
  inEp: number;
  outEp: number;
}

export async function requestFastbootDevice(picker: UsbPicker): Promise<FastbootUsbDevice> {
  let device: FastbootUsbDevice;
  try {
    device = await picker.requestDevice({
      filters: [
        {
          classCode: FASTBOOT_CLASS,
          subclassCode: FASTBOOT_SUBCLASS,
          protocolCode: FASTBOOT_PROTOCOL,
        },
      ],
    });
  } catch (err) {
    throw translatePickerError(err);
  }
  try {
    await device.open();
    await claimFastbootInterface(device);
  } catch (err) {
    // Never leave an opened device behind on a failed claim.
    try {
      await device.close();
    } catch {
      // best effort — original error below is the one that matters
    }
    throw err;
  }
  return device;
}

async function claimFastbootInterface(device: FastbootUsbDevice): Promise<Endpoints> {
  for (const config of device.configurations) {
    const found = findFastbootEndpoints(config);
    if (found === null) {
      continue;
    }
    await device.selectConfiguration(config.configurationValue);
    try {
      await device.claimInterface(found.iface);
    } catch {
      throw new UsbFastbootError(
        "Could not claim the fastboot USB interface. Stop any running `adb`/`fastboot` on this computer and retry.",
      );
    }
    return found;
  }
  throw new UsbFastbootError(
    "No fastboot interface on that USB device. Boot the phone into bootloader mode and retry.",
  );
}

function findFastbootEndpoints(config: UsbConfigSnap): Endpoints | null {
  for (const iface of config.interfaces) {
    for (const alt of iface.alternates) {
      if (
        alt.interfaceClass !== FASTBOOT_CLASS ||
        alt.interfaceSubclass !== FASTBOOT_SUBCLASS ||
        alt.interfaceProtocol !== FASTBOOT_PROTOCOL
      ) {
        continue;
      }
      const inn = alt.endpoints.find((e) => e.direction === "in" && e.type === "bulk");
      const out = alt.endpoints.find((e) => e.direction === "out" && e.type === "bulk");
      if (inn === undefined || out === undefined) {
        continue;
      }
      return { iface: iface.interfaceNumber, inEp: inn.endpointNumber, outEp: out.endpointNumber };
    }
  }
  return null;
}

export interface UsbConfigSnap {
  configurationValue: number;
  interfaces: readonly {
    interfaceNumber: number;
    alternates: readonly {
      interfaceClass: number;
      interfaceSubclass: number;
      interfaceProtocol: number;
      endpoints: readonly { direction: "in" | "out"; type: string; endpointNumber: number }[];
    }[];
  }[];
}

/**
 * Build a Transport over a claimed fastboot device. Reads forward the given
 * AbortSignal; close() yields one macrotask first so an aborted in-flight
 * transferIn can unwind before release (adb-pipe F1 pattern), then releases
 * best-effort — a rebooting device may already be gone.
 */
export async function webUsbTransport(
  picker: UsbPicker,
  options: { signal?: AbortSignal } = {},
): Promise<(Transport & { close(): Promise<void> })> {
  const device = await requestFastbootDevice(picker);
  const ends = mustFind(device);
  return attachTransport(device, ends, options.signal);
}

function mustFind(device: FastbootUsbDevice): Endpoints {
  for (const config of device.configurations) {
    const found = findFastbootEndpoints(config);
    if (found !== null) {
      return found;
    }
  }
  throw new UsbFastbootError("fastboot endpoints disappeared after claim");
}

function attachTransport(
  device: FastbootUsbDevice,
  ends: Endpoints,
  outerSignal?: AbortSignal,
): Transport & { close(): Promise<void> } {
  return {
    async send(command: string): Promise<void> {
      const encoded = encodeCommand(command);
      const result = await device.transferOut(ends.outEp, encoded);
      if (result.status !== "ok") {
        throw new UsbFastbootError(`fastboot USB write failed (${result.status})`);
      }
    },
    async readPacket(): Promise<Uint8Array> {
      const controller = mergeSignals(outerSignal);
      try {
        const result = await device.transferIn(ends.inEp, PACKET_SIZE, { signal: controller });
        if (result.status !== "ok" || result.data === undefined) {
          throw new UsbFastbootError(`fastboot USB read failed (${result.status})`);
        }
        return toBytes(result.data);
      } catch (err) {
        throw classifyTransferError(err);
      }
    },
    async transfer(data: Uint8Array): Promise<void> {
      const result = await device.transferOut(ends.outEp, data);
      if (result.status !== "ok") {
        throw new UsbFastbootError(`fastboot USB payload write failed (${result.status})`);
      }
    },
    async close(): Promise<void> {
      await new Promise<void>((resolve) => {
        setTimeout(resolve, 0);
      });
      try {
        await device.releaseInterface(ends.iface);
      } catch {
        // device may already have dropped (e.g. reboot command)
      }
      try {
        await device.close();
      } catch {
        // ignore
      }
    },
  };
}

/**
 * Normalize a WebUSB transferIn DataView into bytes. Defensive against
 * mocked/quirky implementations whose `data` may be a plain object or an
 * empty view — real WebUSB always delivers a DataView over an ArrayBuffer.
 */
export function toBytes(view: DataView | Uint8Array | ArrayLike<number>): Uint8Array {
  if (view instanceof Uint8Array) {
    return new Uint8Array(view.buffer, view.byteOffset, view.byteLength);
  }
  if (typeof ArrayBuffer !== "undefined" && view instanceof ArrayBuffer) {
    return new Uint8Array(view);
  }
  if (ArrayBuffer.isView(view)) {
    const asView = view as unknown as DataView;
    const byteLength = typeof asView.byteLength === "number" ? asView.byteLength : 0;
    const buffer = (asView as { buffer?: ArrayBuffer }).buffer ?? new ArrayBuffer(byteLength);
    if (
      byteLength > 0 &&
      buffer.byteLength >= (asView.byteOffset ?? 0) + byteLength &&
      typeof (asView as { getUint8?: unknown }).getUint8 === "function"
    ) {
      return new Uint8Array(buffer, asView.byteOffset ?? 0, byteLength);
    }
  }
  // Last resort: element-wise copy (handles array-likes from test doubles).
  const arrayLike = view as ArrayLike<number>;
  const out = new Uint8Array(arrayLike.length ?? 0);
  for (let i = 0; i < out.length; i += 1) {
    out[i] = arrayLike[i] ?? 0;
  }
  return out;
}

function mergeSignals(outer?: AbortSignal): AbortSignal {
  if (typeof AbortSignal.any === "function") {
    return outer === undefined ? new AbortController().signal : AbortSignal.any([outer]);
  }
  if (outer === undefined) {
    return new AbortController().signal;
  }
  return outer;
}

/** Explicit DOMException classification — never swallow silently. */
export function classifyTransferError(err: unknown): Error {
  if (err instanceof DOMException) {
    switch (err.name) {
      case "AbortError":
        return new UsbFastbootError("fastboot read aborted");
      case "NotFoundError":
        return new UsbFastbootError("fastboot USB device disappeared");
      case "InvalidStateError":
        return new UsbFastbootError("fastboot USB device is not open");
      case "NoError":
        break;
      default:
        return new UsbFastbootError(`fastboot USB error (${err.name})`);
    }
  }
  if (err instanceof Error) {
    return err;
  }
  return new UsbFastbootError("fastboot USB transfer failed");
}

function translatePickerError(err: unknown): UsbFastbootError {
  if (err instanceof DOMException && err.name === "NotFoundError") {
    return new UsbFastbootError("No device was selected in the browser USB list.");
  }
  if (err instanceof DOMException && err.name === "SecurityError") {
    return new UsbFastbootError("WebUSB access was denied by browser policy.");
  }
  if (err instanceof Error) {
    return new UsbFastbootError(err.message);
  }
  return new UsbFastbootError("WebUSB fastboot request failed");
}
