import { AdbError } from "../src/errors.js";
import type { AdbChunkIO } from "./adb-pipe.js";

const ADB_CLASS = 255;
const ADB_SUBCLASS = 66;
const ADB_PROTOCOL = 1;
const CHUNK = 4096;

export interface UsbDeviceHandle {
  configurations: readonly UsbConfigSnap[];
  configuration: UsbConfigSnap | null;
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
  ): Promise<{
    status: string;
    data?: DataView;
  }>;
}

export interface UsbConfigSnap {
  configurationValue: number;
  interfaces: readonly UsbIfaceSnap[];
}

export interface UsbIfaceSnap {
  interfaceNumber: number;
  alternates: readonly {
    interfaceClass: number;
    interfaceSubclass: number;
    interfaceProtocol: number;
    endpoints: readonly {
      direction: "in" | "out";
      type: string;
      endpointNumber: number;
    }[];
  }[];
}

export interface UsbPicker {
  requestDevice(options: {
    filters: { classCode: number; subclassCode: number; protocolCode: number }[];
  }): Promise<UsbDeviceHandle>;
}

export function browserUsbPicker(): UsbPicker | null {
  if (typeof navigator === "undefined") {
    return null;
  }
  const holder = navigator as Navigator & { usb?: UsbPicker };
  return holder.usb ?? null;
}

export async function openAdbUsb(picker: UsbPicker): Promise<AdbChunkIO> {
  let device: UsbDeviceHandle;
  try {
    device = await picker.requestDevice({
      filters: [
        { classCode: ADB_CLASS, subclassCode: ADB_SUBCLASS, protocolCode: ADB_PROTOCOL },
      ],
    });
  } catch (err) {
    throw translatePickerError(err);
  }
  await device.open();
  const match = await claimAdbInterface(device);
  return usbChunkIo(device, match);
}

async function claimAdbInterface(
  device: UsbDeviceHandle,
): Promise<{ iface: number; inEp: number; outEp: number }> {
  for (const config of device.configurations) {
    const found = findAdbEndpoints(config);
    if (found === null) {
      continue;
    }
    await device.selectConfiguration(config.configurationValue);
    try {
      await device.claimInterface(found.iface);
    } catch {
      throw new AdbError(
        "Could not claim the ADB USB interface. Stop `adb` on this computer (`adb kill-server`) and retry.",
      );
    }
    return found;
  }
  throw new AdbError(
    "No ADB interface on that USB device. Enable USB debugging, pick the Pixel, or hold volume-down for Fastboot.",
  );
}

function findAdbEndpoints(
  config: UsbConfigSnap,
): { iface: number; inEp: number; outEp: number } | null {
  for (const iface of config.interfaces) {
    const alt = iface.alternates[0];
    if (
      alt === undefined ||
      alt.interfaceClass !== ADB_CLASS ||
      alt.interfaceSubclass !== ADB_SUBCLASS ||
      alt.interfaceProtocol !== ADB_PROTOCOL
    ) {
      continue;
    }
    const inn = alt.endpoints.find((e) => e.direction === "in" && e.type === "bulk");
    const out = alt.endpoints.find((e) => e.direction === "out" && e.type === "bulk");
    if (inn === undefined || out === undefined) {
      continue;
    }
    return {
      iface: iface.interfaceNumber,
      inEp: inn.endpointNumber,
      outEp: out.endpointNumber,
    };
  }
  return null;
}

function usbChunkIo(
  device: UsbDeviceHandle,
  ends: { iface: number; inEp: number; outEp: number },
): AdbChunkIO {
  return {
    async write(data: Uint8Array): Promise<void> {
      const result = await device.transferOut(ends.outEp, data);
      if (result.status !== "ok") {
        throw new AdbError(`ADB USB write failed (${result.status})`);
      }
    },
    async readChunk(signal?: AbortSignal): Promise<Uint8Array> {
      const result = await device.transferIn(
        ends.inEp,
        CHUNK,
        signal === undefined ? {} : { signal },
      );
      if (result.status !== "ok" || result.data === undefined) {
        throw new AdbError(`ADB USB read failed (${result.status})`);
      }
      return new Uint8Array(result.data.buffer, result.data.byteOffset, result.data.byteLength);
    },
    async close(): Promise<void> {
      // A release while a transfer is still in flight is rejected by WebUSB,
      // which leaks the claimed interface (F1). Bound the wait so a hung
      // transfer cannot stall close() forever.
      await new Promise<void>((resolve) => {
        setTimeout(resolve, 0);
      });
      try {
        await device.releaseInterface(ends.iface);
      } catch {
        // device may already have dropped after reboot
      }
      try {
        await device.close();
      } catch {
        // ignore
      }
    },
  };
}

function translatePickerError(err: unknown): AdbError {
  if (err instanceof DOMException && err.name === "NotFoundError") {
    return new AdbError("No Pixel was selected. Choose the Android device in the browser USB list.");
  }
  if (err instanceof Error) {
    return new AdbError(err.message);
  }
  return new AdbError("WebUSB ADB request failed");
}
