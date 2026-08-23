import { AdbError } from "../src/errors.js";
import { BufferedAdbPipe, type AdbChunkIO } from "./adb-pipe.js";
import { localStorageKeyStore, type AdbKeyStore } from "./adb-rsa.js";
import { adbRebootBootloader } from "./adb-session.js";
import { browserUsbPicker, openAdbUsb, type UsbPicker } from "./adb-usb.js";

const REBOOT_WAIT_MS = 90_000;

export interface RebootToFastbootDeps {
  io?: AdbChunkIO;
  usb?: UsbPicker;
  store?: AdbKeyStore;
  /** Test hook; production keeps the 90 s "Allow USB debugging" budget. */
  timeoutMs?: number;
}

export function webUsbAvailable(): boolean {
  return browserUsbPicker() !== null;
}

/**
 * Talk ADB over WebUSB and send `reboot:bootloader`.
 * Does not flash. OEM unlocking and USB debugging stay on-device settings.
 */
export async function rebootAndroidToBootloader(
  deps: RebootToFastbootDeps = {},
): Promise<void> {
  const store = deps.store ?? localStorageKeyStore();
  const io = deps.io ?? (await openFromPicker(deps.usb));
  const pipe = new BufferedAdbPipe(io);
  try {
    await withTimeout(
      adbRebootBootloader(pipe, store),
      deps.timeoutMs ?? REBOOT_WAIT_MS,
      "Timed out waiting for the Pixel to allow USB debugging or enter Fastboot.",
    );
  } finally {
    // cancel() aborts any in-flight transferIn first; close() then yields so
    // the transfer can unwind before releaseInterface/close run (F1: no
    // claimed-interface or device-handle leak on timeout).
    pipe.cancel();
    await pipe.close();
  }
}

async function withTimeout<T>(work: Promise<T>, ms: number, message: string): Promise<T> {
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(() => {
      reject(new AdbError(message));
    }, ms);
  });
  try {
    return await Promise.race([work, timeout]);
  } finally {
    if (timer !== undefined) {
      clearTimeout(timer);
    }
  }
}

async function openFromPicker(usb: UsbPicker | undefined): Promise<AdbChunkIO> {
  const picker = usb ?? browserUsbPicker();
  if (picker === null || picker === undefined) {
    throw new AdbError(
      "This browser has no WebUSB. Use Chromium, or run vendor/guardtalk/scripts/reboot-to-fastboot.sh on the USB host.",
    );
  }
  return openAdbUsb(picker);
}
