import assert from "node:assert/strict";
import { test } from "node:test";
import { AdbError } from "../src/errors.js";
import { bytesBeToBigInt, cString, modPow } from "../wizard/adb-bytes.js";
import {
  A_AUTH,
  A_CNXN,
  A_OKAY,
  A_OPEN,
  A_VERSION,
  AUTH_RSAPUBLICKEY,
  AUTH_SIGNATURE,
  AUTH_TOKEN,
  HEADER_LEN,
  MAX_PAYLOAD,
  checksum,
  decodeHeader,
  encodePacket,
} from "../wizard/adb-packet.js";
import { BufferedAdbPipe, MAX_LEFTOVER_BYTES, type AdbChunkIO } from "../wizard/adb-pipe.js";
import { rebootAndroidToBootloader, webUsbAvailable } from "../wizard/adb-reboot.js";
import {
  ADB_KEY_STORE_ID,
  loadOrCreateAdbKey,
  memoryKeyStore,
  parseJwk,
  signAdbToken,
  type AdbKeyStore,
} from "../wizard/adb-rsa.js";
import { InstallWizard } from "../wizard/session.js";

const TOKEN = Uint8Array.of(
  1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16, 17, 18, 19, 20,
);

const SHA1_DIGEST_INFO_PREFIX = Uint8Array.of(
  0x30, 0x21, 0x30, 0x09, 0x06, 0x05, 0x2b, 0x0e, 0x03, 0x02, 0x1a, 0x05, 0x00,
  0x04, 0x14,
);

function emForToken(token: Uint8Array): Uint8Array {
  const digestInfo = new Uint8Array(SHA1_DIGEST_INFO_PREFIX.length + token.length);
  digestInfo.set(SHA1_DIGEST_INFO_PREFIX, 0);
  digestInfo.set(token, SHA1_DIGEST_INFO_PREFIX.length);
  const psLen = 256 - digestInfo.length - 3;
  const em = new Uint8Array(256);
  em[0] = 0x00;
  em[1] = 0x01;
  em.fill(0xff, 2, 2 + psLen);
  em[2 + psLen] = 0x00;
  em.set(digestInfo, 3 + psLen);
  return em;
}

class ByteInbox {
  private chunks: Uint8Array[] = [];
  private waiters: Array<(chunk: Uint8Array) => void> = [];

  push(chunk: Uint8Array): void {
    const waiter = this.waiters.shift();
    if (waiter !== undefined) {
      waiter(chunk);
      return;
    }
    this.chunks.push(chunk);
  }

  pull(): Promise<Uint8Array> {
    const next = this.chunks.shift();
    if (next !== undefined) {
      return Promise.resolve(next);
    }
    return new Promise((resolve) => {
      this.waiters.push(resolve);
    });
  }
}

function linkedIo(): {
  host: AdbChunkIO;
  device: AdbChunkIO;
  toDevice: ByteInbox;
  toHost: ByteInbox;
} {
  const toDevice = new ByteInbox();
  const toHost = new ByteInbox();
  return {
    toDevice,
    toHost,
    host: {
      write: async (data) => {
        toDevice.push(data);
      },
      readChunk: () => toHost.pull(),
      close: async () => undefined,
    },
    device: {
      write: async (data) => {
        toHost.push(data);
      },
      readChunk: () => toDevice.pull(),
      close: async () => undefined,
    },
  };
}

function chunkIo(chunks: Uint8Array[]): AdbChunkIO {
  const queue = [...chunks];
  return {
    write: async () => undefined,
    readChunk: async () => {
      const next = queue.shift();
      if (next === undefined) {
        throw new AdbError("ADB USB stream ended");
      }
      return next;
    },
    close: async () => undefined,
  };
}

let warmStorePromise: Promise<AdbKeyStore> | undefined;

/**
 * RSA keygen takes longer than a test timeout; generate one key up front and
 * reuse the populated store across tests that do not mutate it.
 */
function warmStore(): Promise<AdbKeyStore> {
  warmStorePromise ??= (async () => {
    const store = memoryKeyStore();
    await loadOrCreateAdbKey(store);
    return store;
  })();
  return warmStorePromise;
}

async function fakePhone(
  io: AdbChunkIO,
  mode: "known-key" | "new-key" | "open-adb",
): Promise<string> {
  const pipe = new BufferedAdbPipe(io);
  const hello = await pipe.readPacket();
  assert.equal(hello.command, A_CNXN);
  if (mode !== "open-adb") {
    await pipe.writePacket(A_AUTH, AUTH_TOKEN, 0, TOKEN);
    const auth = await pipe.readPacket();
    assert.equal(auth.command, A_AUTH);
    assert.equal(auth.arg0, AUTH_SIGNATURE);
    if (mode === "new-key") {
      await pipe.writePacket(A_AUTH, AUTH_TOKEN, 0, TOKEN);
      const pub = await pipe.readPacket();
      assert.equal(pub.command, A_AUTH);
      assert.equal(pub.arg0, AUTH_RSAPUBLICKEY);
      assert.match(new TextDecoder().decode(pub.data), /guardtalk@web/);
    }
  }
  await pipe.writePacket(A_CNXN, A_VERSION, MAX_PAYLOAD, cString("device::"));
  const open = await pipe.readPacket();
  assert.equal(open.command, A_OPEN);
  assert.equal(open.arg1, 0);
  const service = new TextDecoder().decode(open.data);
  // Echo the host's localId back as the OKAY remote-id (arg0), like adbd.
  await pipe.writePacket(A_OKAY, open.arg1, open.arg0, new Uint8Array());
  return service;
}

test("webUsbAvailable is false in Node", () => {
  assert.equal(webUsbAvailable(), false);
});

test("ADB packet encode/decode preserves checksum", () => {
  const data = cString("host::");
  const raw = encodePacket(A_CNXN, A_VERSION, MAX_PAYLOAD, data);
  const header = decodeHeader(raw.slice(0, 24));
  assert.equal(header.command, A_CNXN);
  assert.equal(header.length, data.length);
  assert.equal(header.check, checksum(data));
});

test("wizard sends reboot:bootloader after a known ADB key", async () => {
  const pair = linkedIo();
  const phone = fakePhone(pair.device, "known-key");
  const host = rebootAndroidToBootloader({
    io: pair.host,
    store: memoryKeyStore(),
  });
  const service = await phone;
  await host;
  assert.equal(service, "reboot:bootloader\0");
});

test("wizard offers the browser RSA key when the Pixel is new", async () => {
  const pair = linkedIo();
  const phone = fakePhone(pair.device, "new-key");
  await rebootAndroidToBootloader({
    io: pair.host,
    store: memoryKeyStore(),
  });
  assert.equal(await phone, "reboot:bootloader\0");
});

test("wizard skips AUTH when the device sends CNXN immediately", async () => {
  const pair = linkedIo();
  const phone = fakePhone(pair.device, "open-adb");
  await rebootAndroidToBootloader({
    io: pair.host,
    store: memoryKeyStore(),
  });
  assert.equal(await phone, "reboot:bootloader\0");
});

test("InstallWizard.rebootToFastboot uses the same ADB path", async () => {
  const pair = linkedIo();
  const phone = fakePhone(pair.device, "known-key");
  const session = new InstallWizard();
  await session.rebootToFastboot({
    io: pair.host,
    store: memoryKeyStore(),
  });
  assert.equal(await phone, "reboot:bootloader\0");
});

test("missing WebUSB picker fails closed", async () => {
  await assert.rejects(
    () => rebootAndroidToBootloader({ store: memoryKeyStore() }),
    AdbError,
  );
});

test("AUTH SIGNATURE verifies as raw RSA over the token (adbd semantics)", async () => {
  const store = await warmStore();
  const key = await loadOrCreateAdbKey(store);
  const sig = signAdbToken(key, TOKEN);
  assert.equal(sig.length, 256);
  const raw = store.get(ADB_KEY_STORE_ID);
  assert.ok(typeof raw === "string");
  // crypto.subtle.verify cannot be used here: WebCrypto RSASSA always hashes
  // the message, while adbd signs the raw 20-byte token as the DigestInfo
  // payload. This is the exact RSASSA-PKCS1-v1_5 verification (RFC 8017
  // §8.2.2 step 2): recover the EM via sig^e mod n and compare byte-for-byte.
  const jwk = parseJwk(raw);
  const e = 65537n;
  const recovered = modPow(bytesBeToBigInt(sig), e, jwk.n);
  assert.equal(recovered, bytesBeToBigInt(emForToken(TOKEN)));
});

test("tampered AUTH SIGNATURE fails raw-RSA verification", async () => {
  const store = await warmStore();
  const key = await loadOrCreateAdbKey(store);
  const sig = signAdbToken(key, TOKEN);
  const raw = store.get(ADB_KEY_STORE_ID);
  assert.ok(typeof raw === "string");
  const jwk = parseJwk(raw);
  const bad = sig.slice();
  bad[0] = (bad[0] ?? 0) ^ 0xff;
  const recovered = modPow(bytesBeToBigInt(bad), 65537n, jwk.n);
  assert.notEqual(recovered, bytesBeToBigInt(emForToken(TOKEN)));
});

test("zero-length payload with check 0 is accepted", async () => {
  const raw = encodePacket(A_OKAY, 1, 1, new Uint8Array());
  assert.equal(decodeHeader(raw.slice(0, 24)).check, 0);
  const pipe = new BufferedAdbPipe(chunkIo([raw]));
  const packet = await pipe.readPacket();
  assert.equal(packet.command, A_OKAY);
  assert.equal(packet.data.length, 0);
});

test("non-empty payload with forged check 0 is rejected", async () => {
  const raw = encodePacket(A_CNXN, A_VERSION, MAX_PAYLOAD, cString("device::"));
  raw[16] = 0;
  raw[17] = 0;
  raw[18] = 0;
  raw[19] = 0;
  const pipe = new BufferedAdbPipe(chunkIo([raw]));
  await assert.rejects(() => pipe.readPacket(), /checksum mismatch/);
});

test("leftover buffer growth is capped for hostile chunks", async () => {
  const hostile = new Uint8Array(MAX_LEFTOVER_BYTES + 1);
  const pipe = new BufferedAdbPipe(chunkIo([hostile]));
  await assert.rejects(() => pipe.readPacket(), /exceeds the .*-byte cap/);
});

test("timeout aborts the in-flight read and closes the device", async () => {
  let aborted = false;
  let closed = false;
  const io: AdbChunkIO = {
    write: async () => undefined,
    readChunk: (signal?: AbortSignal) =>
      new Promise<Uint8Array>((_, reject) => {
        signal?.addEventListener("abort", () => {
          aborted = true;
          reject(new DOMException("The transfer was aborted.", "AbortError"));
        });
      }),
    close: async () => {
      closed = true;
    },
  };
  await assert.rejects(
    async () =>
      rebootAndroidToBootloader({
        io,
        store: await warmStore(),
        timeoutMs: 25,
      }),
    /Timed out/,
  );
  assert.equal(aborted, true);
  await new Promise((resolve) => {
    setTimeout(resolve, 5);
  });
  assert.equal(closed, true);
});

test("post-OPEN device drop still reports reboot sent", async () => {
  const pair = linkedIo();
  const phone = (async () => {
    const pipe = new BufferedAdbPipe(pair.device);
    await pipe.readPacket();
    await pipe.writePacket(A_CNXN, A_VERSION, MAX_PAYLOAD, cString("device::"));
    await pipe.readPacket();
    // Device drops off USB instead of ACKing: zero-length read = disconnect.
    pair.toHost.push(new Uint8Array(0));
  })();
  await rebootAndroidToBootloader({ io: pair.host, store: await warmStore() });
  await phone;
});

test("real USB failure after OPEN surfaces as AdbError", async () => {
  // Scripted host reads: device:: CNXN banner (24+8) — an already-authorized
  // device skips AUTH entirely — then the USB stack dies with
  // InvalidStateError on the post-OPEN OKAY read, where waitForRebootAck
  // must translate it instead of reporting success.
  const banner = encodePacket(A_CNXN, A_VERSION, MAX_PAYLOAD, cString("device::"));
  const script: Uint8Array[] = [
    banner.slice(0, HEADER_LEN),
    banner.slice(HEADER_LEN),
  ];
  const io: AdbChunkIO = {
    write: async () => undefined,
    readChunk: async () => {
      const next = script.shift();
      if (next !== undefined) {
        return next;
      }
      throw new DOMException("interface detached", "InvalidStateError");
    },
    close: async () => undefined,
  };
  await assert.rejects(
    async () =>
      rebootAndroidToBootloader({ io, store: await warmStore(), timeoutMs: 5000 }),
    /InvalidStateError/,
  );
});

test("unexpected packet after OPEN is an error, not success", async () => {
  const pair = linkedIo();
  const phone = (async () => {
    const pipe = new BufferedAdbPipe(pair.device);
    await pipe.readPacket();
    await pipe.writePacket(A_CNXN, A_VERSION, MAX_PAYLOAD, cString("device::"));
    await pipe.readPacket();
    await pipe.writePacket(A_AUTH, AUTH_TOKEN, 0, TOKEN);
  })();
  await assert.rejects(
    async () =>
      rebootAndroidToBootloader({ io: pair.host, store: await warmStore() }),
    /was rejected \(AUTH\)/,
  );
  await phone;
});

test("OKAY targeting the wrong local id is rejected", async () => {
  const pair = linkedIo();
  const phone = (async () => {
    const pipe = new BufferedAdbPipe(pair.device);
    await pipe.readPacket();
    await pipe.writePacket(A_CNXN, A_VERSION, MAX_PAYLOAD, cString("device::"));
    const open = await pipe.readPacket();
    await pipe.writePacket(A_OKAY, open.arg1, open.arg0 + 7, new Uint8Array());
  })();
  await assert.rejects(
    async () =>
      rebootAndroidToBootloader({ io: pair.host, store: await warmStore() }),
    /local id/,
  );
  await phone;
});
