import { FastbootError } from "./errors.js";
import type {
  CommandResult,
  FastbootTransport,
  FlashOptions,
  ReconnectHook,
} from "./types.js";

/**
 * Subset of kdrag0n/fastboot.js FastbootDevice used by the adapter.
 * Pin android-fastboot at commit ffe7e270 or newer when the wizard wires WebUSB.
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

/** Wrap a real android-fastboot FastbootDevice without importing the library. */
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
