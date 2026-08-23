import { AdbError } from "../src/errors.js";
import { cString, utf8 } from "./adb-bytes.js";
import {
  AUTH_RSAPUBLICKEY,
  AUTH_SIGNATURE,
  AUTH_TOKEN,
  A_AUTH,
  A_CLSE,
  A_CNXN,
  A_OKAY,
  A_OPEN,
  A_VERSION,
  MAX_PAYLOAD,
  commandName,
  type AdbPacket,
} from "./adb-packet.js";
import { BufferedAdbPipe } from "./adb-pipe.js";
import {
  androidPublicKey,
  loadOrCreateAdbKey,
  signAdbToken,
  type AdbKeyStore,
  type AdbRsaKey,
} from "./adb-rsa.js";

const LOCAL_ID = 1;
const REBOOT_SERVICE = "reboot:bootloader";

/**
 * After `reboot:bootloader` adbd may ACK (OKAY/CLSE) or simply drop off USB
 * when it reboots. Only those expected outcomes count as success; every other
 * failure surfaces as AdbError with the original error name preserved (F2).
 */
function isExpectedRebootDisconnect(err: unknown): boolean {
  if (err instanceof AdbError) {
    return /stream ended|stream cancelled/i.test(err.message);
  }
  if (err instanceof DOMException) {
    return (
      err.name === "NetworkError" ||
      err.name === "NoDeviceError" ||
      err.name === "NotFoundError" ||
      err.name === "AbortError"
    );
  }
  return false;
}

export async function adbRebootBootloader(
  pipe: BufferedAdbPipe,
  store: AdbKeyStore,
): Promise<void> {
  const key = await loadOrCreateAdbKey(store);
  await pipe.writePacket(A_CNXN, A_VERSION, MAX_PAYLOAD, cString("host::"));
  const banner = await authenticate(pipe, key);
  if (banner.command !== A_CNXN) {
    throw new AdbError(`expected CNXN after AUTH, got ${commandName(banner.command)}`);
  }
  await pipe.writePacket(A_OPEN, LOCAL_ID, 0, cString(REBOOT_SERVICE));
  await waitForRebootAck(pipe, LOCAL_ID);
}

async function authenticate(
  pipe: BufferedAdbPipe,
  key: AdbRsaKey,
): Promise<AdbPacket> {
  let offeredPublicKey = false;
  for (let i = 0; i < 8; i++) {
    const packet = await pipe.readPacket();
    if (packet.command === A_CNXN) {
      return packet;
    }
    if (packet.command !== A_AUTH || packet.arg0 !== AUTH_TOKEN) {
      throw new AdbError(`unexpected ADB packet ${commandName(packet.command)}`);
    }
    if (!offeredPublicKey) {
      await pipe.writePacket(
        A_AUTH,
        AUTH_SIGNATURE,
        0,
        signAdbToken(key, packet.data),
      );
      offeredPublicKey = true;
      continue;
    }
    await pipe.writePacket(
      A_AUTH,
      AUTH_RSAPUBLICKEY,
      0,
      utf8(androidPublicKey(key)),
    );
  }
  throw new AdbError(
    "Pixel did not accept the browser ADB key. Unlock the phone and tap Allow USB debugging.",
  );
}

async function waitForRebootAck(
  pipe: BufferedAdbPipe,
  localId: number,
): Promise<void> {
  let packet: AdbPacket;
  try {
    packet = await pipe.readPacket();
  } catch (err) {
    if (isExpectedRebootDisconnect(err)) {
      return;
    }
    if (err instanceof DOMException) {
      throw new AdbError(`ADB USB failure after OPEN (${err.name})`);
    }
    throw err;
  }
  if (packet.command === A_CLSE) {
    return;
  }
  if (packet.command !== A_OKAY) {
    throw new AdbError(
      `reboot:bootloader was rejected (${commandName(packet.command)})`,
    );
  }
  // A_OKAY.arg0 is the responder's id and arg1 echoes our OPEN localId.
  if (packet.arg1 !== localId) {
    throw new AdbError(
      `reboot:bootloader OKAY targets local id ${String(packet.arg1)}, expected ${String(localId)}`,
    );
  }
}
