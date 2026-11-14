import {
  FastbootError,
  UsbDisconnectError,
  UsbPermissionError,
  UsbTimeoutError,
} from "./errors.js";
import type {
  CommandResult,
  FastbootTransport,
  FlashOptions,
  ReconnectHook,
} from "./types.js";

/**
 * Package name of the Law-22 dependency declared (pinned to an exact commit) in
 * `package.json`. Kept as a variable so the module graph never gets a static
 * edge to it: the dry-run/simulated path must typecheck and run even where the
 * package is absent, and only the live path may load WebUSB code.
 */
export const ANDROID_FASTBOOT_SPECIFIER = "android-fastboot";

/**
 * Subset of kdrag0n/fastboot.js FastbootDevice used by the adapter.
 * Pinned to commit ffe7e270061b95fe0f0f3abd1aa7d3c28999d1d9 (see package.json).
 */
export interface AndroidFastbootDevice {
  connect(): Promise<void>;
  getVariable(name: string): Promise<string | null>;
  runCommand(command: string): Promise<{ text?: string } | void>;
  flashBlob(partition: string, blob: Blob): Promise<void>;
  upload?(blob: Blob): Promise<void>;
  reboot(
    mode?: string,
    wait?: boolean,
    onReconnect?: ReconnectHook,
  ): Promise<void>;
  device?: { close?: () => Promise<void> } | null;
}

export interface AdaptFastbootOptions {
  /** Optional timeout (ms) for getVar/runCommand/connect. */
  readonly commandTimeoutMs?: number;
  /** Optional timeout (ms) for rebootBootloader/rebootFastboot reconnect waits. */
  readonly rebootTimeoutMs?: number;
}

/** Minimal structural view of the pinned `android-fastboot` entry point. */
export interface AndroidFastbootModule {
  FastbootDevice: new () => AndroidFastbootDevice;
}

/** Classify a WebUSB / fastboot error into an explicit recoverable USB error when applicable. */
export function classifyUsbError(err: unknown, context: string): FastbootError {
  if (err instanceof FastbootError) {
    return err;
  }
  const name =
    err instanceof Error
      ? (err as { name?: string }).name ?? err.constructor.name
      : "";
  const message = err instanceof Error ? err.message : String(err);

  if (name === "NotFoundError" || name === "SecurityError" || name === "NotAllowedError") {
    return new UsbPermissionError(context, message);
  }
  if (
    name === "NetworkError" ||
    name === "NoDeviceError" ||
    /disconnect|device\s*lost|not\s*connected|transfer\s*error/i.test(message)
  ) {
    return new UsbDisconnectError(context, message);
  }
  if (name === "AbortError" || name === "TimeoutError" || /timed?\s*out/i.test(message)) {
    return new UsbTimeoutError(context, message);
  }
  return new FastbootError(message || `fastboot ${context} failed`);
}

/** Wrap a real android-fastboot FastbootDevice behind the FastbootTransport interface. */
export function adaptAndroidFastboot(
  device: AndroidFastbootDevice,
  options: AdaptFastbootOptions = {},
): FastbootTransport {
  const cmdTimeout = options.commandTimeoutMs;
  const rebootTimeout = options.rebootTimeoutMs;

  return {
    dryRun: false,
    connect: async () => {
      try {
        await withUsbTimeout(device.connect(), cmdTimeout, "connect");
      } catch (err) {
        throw classifyUsbError(err, "connect");
      }
    },
    getVar: async (name) => {
      let value: string | null;
      try {
        value = await withUsbTimeout(device.getVariable(name), cmdTimeout, `getvar ${name}`);
      } catch (err) {
        throw classifyUsbError(err, `getvar ${name}`);
      }
      if (value === null || value === "") {
        throw new FastbootError(`getvar ${name} returned empty`);
      }
      return value;
    },
    runCommand: async (command) => mapCommand(device, command, cmdTimeout),
    flash: async (partition, data, flashOptions) => {
      try {
        await device.flashBlob(partitionName(partition, flashOptions), blobFrom(data));
      } catch (err) {
        throw classifyUsbError(err, `flash ${partition}`);
      }
    },
    rebootBootloader: async (onReconnect) => {
      try {
        await withUsbTimeout(
          device.reboot("bootloader", true, onReconnect),
          rebootTimeout,
          "reboot-bootloader",
        );
      } catch (err) {
        throw classifyUsbError(err, "reboot-bootloader");
      }
    },
    rebootFastboot: async (onReconnect) => {
      try {
        await withUsbTimeout(
          device.reboot("fastboot", true, onReconnect),
          rebootTimeout,
          "reboot-fastboot",
        );
      } catch (err) {
        throw classifyUsbError(err, "reboot-fastboot");
      }
    },
    wipeSuper: async (data) => {
      if (typeof device.upload !== "function") {
        throw new FastbootError("android-fastboot device does not support upload() for wipe-super");
      }
      try {
        await device.upload(blobFrom(data));
      } catch (err) {
        throw classifyUsbError(err, "wipe-super upload");
      }
      const res = await mapCommand(device, "update-super:super:wipe", cmdTimeout);
      if (!res.ok) {
        throw new FastbootError(res.text ?? "update-super:super:wipe failed");
      }
    },
    close: async () => {
      if (typeof device.device?.close === "function") {
        try {
          await device.device.close();
        } catch {
          // Best-effort close on teardown
        }
      }
    },
  };
}

/**
 * Load the pinned dependency. Callable only from the live path (never at module
 * scope); a missing or malformed package fails closed with a FastbootError
 * instead of degrading into a transport that pretends to work.
 */
export async function importAndroidFastboot(): Promise<AndroidFastbootModule> {
  let loaded: unknown;
  try {
    loaded = await import(ANDROID_FASTBOOT_SPECIFIER);
  } catch (error) {
    const detail = error instanceof Error ? error.message : String(error);
    throw new FastbootError(
      `cannot load '${ANDROID_FASTBOOT_SPECIFIER}' (${detail}); ` +
        "run `npm install` in the installer root",
    );
  }
  return assertAndroidFastbootModule(loaded);
}

export interface AndroidFastbootConnectOptions extends AdaptFastbootOptions {
  /**
   * Test seam: supply the module explicitly instead of importing the pinned
   * package. Production callers omit it and get the real library.
   */
  readonly module?: AndroidFastbootModule;
}

/**
 * The real WebUSB live transport: load `android-fastboot`, connect, and wrap
 * the device in the existing FastbootTransport interface.
 *
 * The returned transport carries `dryRun: false`, so `FlashOrchestrator`
 * refuses `executePlan()` and `lock()` with `LiveExecuteHoldError` (DEC-009)
 * unless explicitly opted in, and `LIVE_FLASH_CLAIMED` stays `false`.
 */
export async function connectAndroidFastboot(
  options: AndroidFastbootConnectOptions = {},
): Promise<FastbootTransport> {
  const module = assertAndroidFastbootModule(
    options.module ?? (await importAndroidFastboot()),
  );
  const device = new module.FastbootDevice();
  const transport = adaptAndroidFastboot(device, options);
  await transport.connect();
  return transport;
}

function assertAndroidFastbootModule(
  loaded: unknown,
): AndroidFastbootModule {
  const holder = loaded as { FastbootDevice?: unknown } | null;
  if (typeof holder?.FastbootDevice !== "function") {
    throw new FastbootError(
      `'${ANDROID_FASTBOOT_SPECIFIER}' does not export a FastbootDevice constructor`,
    );
  }
  return loaded as AndroidFastbootModule;
}

function partitionName(partition: string, options?: FlashOptions): string {
  if (options?.slot === "other") {
    return `${partition}:other`;
  }
  return partition;
}

function blobFrom(data: Uint8Array): Blob {
  const copy = new Uint8Array(data.byteLength);
  copy.set(data);
  return new Blob([copy]);
}

async function withUsbTimeout<T>(
  work: Promise<T>,
  timeoutMs: number | undefined,
  context: string,
): Promise<T> {
  if (timeoutMs === undefined || timeoutMs <= 0) {
    return work;
  }
  let timer: ReturnType<typeof setTimeout> | undefined;
  const timeout = new Promise<never>((_, reject) => {
    timer = setTimeout(() => {
      reject(new UsbTimeoutError(context, `exceeded ${String(timeoutMs)}ms`));
    }, timeoutMs);
  });
  try {
    return await Promise.race([work, timeout]);
  } finally {
    if (timer !== undefined) {
      clearTimeout(timer);
    }
  }
}

async function mapCommand(
  device: AndroidFastbootDevice,
  command: string,
  timeoutMs?: number,
): Promise<CommandResult> {
  try {
    const result = await withUsbTimeout(
      device.runCommand(command),
      timeoutMs,
      `command '${command}'`,
    );
    const text = result && "text" in result ? result.text : undefined;
    return { ok: true, ...(text !== undefined ? { text } : {}) };
  } catch (err) {
    if (err instanceof UsbTimeoutError || err instanceof UsbDisconnectError || err instanceof UsbPermissionError) {
      throw err;
    }
    const name = err instanceof Error ? (err as { name?: string }).name ?? "" : "";
    if (name === "NetworkError" || name === "NoDeviceError" || name === "SecurityError" || name === "NotAllowedError") {
      throw classifyUsbError(err, `command '${command}'`);
    }
    const message = err instanceof Error ? err.message : "fastboot command failed";
    return { ok: false, text: message };
  }
}
