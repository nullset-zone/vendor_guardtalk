import { FastbootError } from "./errors.js";
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
  reboot(
    mode?: string,
    wait?: boolean,
    onReconnect?: ReconnectHook,
  ): Promise<void>;
}

/** Minimal structural view of the pinned `android-fastboot` entry point. */
export interface AndroidFastbootModule {
  FastbootDevice: new () => AndroidFastbootDevice;
}

/** Wrap a real android-fastboot FastbootDevice behind the FastbootTransport interface. */
export function adaptAndroidFastboot(
  device: AndroidFastbootDevice,
): FastbootTransport {
  return {
    dryRun: false,
    connect: () => device.connect(),
    getVar: async (name) => {
      const value = await device.getVariable(name);
      if (value === null || value === "") {
        throw new FastbootError(`getvar ${name} returned empty`);
      }
      return value;
    },
    runCommand: async (command) => mapCommand(device, command),
    flash: async (partition, data, options) => {
      await device.flashBlob(partitionName(partition, options), blobFrom(data));
    },
    rebootBootloader: async (onReconnect) => {
      await device.reboot("bootloader", true, onReconnect);
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

export interface AndroidFastbootConnectOptions {
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
 * and `LIVE_FLASH_CLAIMED` stays `false`. Connecting is not a write; nothing
 * here flashes or claims that a flash happened.
 */
export async function connectAndroidFastboot(
  options: AndroidFastbootConnectOptions = {},
): Promise<FastbootTransport> {
  const module = assertAndroidFastbootModule(
    options.module ?? (await importAndroidFastboot()),
  );
  const device = new module.FastbootDevice();
  await device.connect();
  return adaptAndroidFastboot(device);
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

async function mapCommand(
  device: AndroidFastbootDevice,
  command: string,
): Promise<CommandResult> {
  try {
    const result = await device.runCommand(command);
    const text = result && "text" in result ? result.text : undefined;
    return { ok: true, ...(text !== undefined ? { text } : {}) };
  } catch (err) {
    const message = err instanceof Error ? err.message : "fastboot command failed";
    return { ok: false, text: message };
  }
}
