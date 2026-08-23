/**
 * fastboot foundation tests — all against SimulatedDevice (D-011: no real
 * hardware in-session) and mocked USBDevice objects (no USB stack).
 */
import assert from "node:assert/strict";
import { test } from "node:test";
import { FastbootClient, FastbootError } from "../lib/fastboot/client.js";
import {
  decodePacket,
  downloadCommand,
  encodeCommand,
  parseDataSize,
  parseMaxDownloadSize,
  ProtocolError,
  wireRoundTrips,
  wireToCommand,
} from "../lib/fastboot/protocol.js";
import {
  imageDownloadChunks,
  imageTransferUnits,
  isSparseImage,
  OVERSIZE_IMAGE_MESSAGE,
  parseSparseHeader,
  sparseChunks,
  SparseError,
  SPARSE_MAGIC,
} from "../lib/fastboot/sparse.js";
import { SimulatedDevice } from "../lib/fastboot/simulated-device.js";
import {
  classifyTransferError,
  PACKET_SIZE,
  requestFastbootDevice,
  webUsbTransport,
  type FastbootUsbDevice,
  type UsbConfigSnap,
  type UsbPicker,
} from "../lib/fastboot/usb.js";
import { collectingLog } from "../lib/types.js";

// --- protocol.ts -------------------------------------------------------------

test("wire: encode→decode identity for every canonical command", () => {
  const commands = [
    "getvar:product",
    "flash:avb_custom_key",
    "erase:misc",
    "flashing unlock",
    "flashing lock",
    "reboot",
    "reboot-bootloader",
    downloadCommand(1032),
    "OKAY",
    "FAILno such partition",
    "INFOwriting... 42%",
    "DATA00000408",
  ];
  for (const command of commands) {
    assert.equal(wireRoundTrips(command), true, command);
    assert.deepEqual(wireToCommand(encodeCommand(command)), command);
  }
});

test("protocol: download:%08x encoding", () => {
  assert.equal(downloadCommand(0), "download:00000000");
  assert.equal(downloadCommand(1032), "download:00000408");
  assert.equal(downloadCommand(268435456), "download:10000000");
});

test("protocol: DATA size parsing round-trips", () => {
  const packet = decodePacket(encodeCommand("DATA00000408"));
  assert.equal(packet.kind, "DATA");
  assert.equal(parseDataSize(packet), 1032);
});

test("protocol: max-download-size accepts decimal and hex", () => {
  assert.equal(parseMaxDownloadSize("268435456"), 268435456);
  assert.equal(parseMaxDownloadSize("0x10000000"), 268435456);
  assert.throws(() => parseMaxDownloadSize("banana"), ProtocolError);
});

test("protocol: unknown packet prefix rejected", () => {
  assert.throws(() => decodePacket(encodeCommand("WHAT")), ProtocolError);
});

// --- client + simulated device: happy path -----------------------------------

test("client: happy-path flash sequence records exact command order incl. avb_custom_key", async () => {
  const device = new SimulatedDevice({ initiallyUnlocked: true });
  const log = collectingLog();
  const client = new FastbootClient(device, log);

  const product = await client.getvar("product");
  assert.equal(product, "tokay");

  const pkmd = bytes(1032, 0xab);
  const boot = bytes(4096, 0x42);
  const vbmeta = bytes(4096, 0x99);

  await client.flash("avb_custom_key", pkmd);
  await client.flash("boot", boot);
  await client.flash("vbmeta", vbmeta);

  assert.deepEqual([...device.partitions.keys()], ["avb_custom_key", "boot", "vbmeta"]);
  assert.deepEqual(device.partitions.get("avb_custom_key"), pkmd);
  assert.deepEqual(device.partitions.get("boot"), boot);

  // Exact command order on the wire, verbatim.
  const commands = log.lines.filter((l) => l.startsWith("> "));
  assert.deepEqual(commands, [
    "> getvar:product",
    "> getvar:max-download-size",
    `> ${downloadCommand(pkmd.length)}`,
    "> [1032 byte payload]",
    "> flash:avb_custom_key",
    "> getvar:max-download-size",
    `> ${downloadCommand(boot.length)}`,
    `> [${String(boot.length)} byte payload]`,
    "> flash:boot",
    "> getvar:max-download-size",
    `> ${downloadCommand(vbmeta.length)}`,
    `> [${String(vbmeta.length)} byte payload]`,
    "> flash:vbmeta",
  ]);

  // Responses are logged verbatim too.
  assert.ok(log.lines.includes("< OKAYtokay"));
  assert.ok(log.lines.includes("< OKAY"));
});

test("client: getvar FAIL propagates verbatim reason and stops the flow", async () => {
  const device = new SimulatedDevice({ vars: { product: "rango" } });
  const client = new FastbootClient(device);
  assert.equal(await client.getvar("product"), "rango");

  const unknown = new SimulatedDevice();
  const failing = new FastbootClient(unknown);
  await assert.rejects(failing.getvar("battery-soc-ok"), (err: unknown) => {
    assert.ok(err instanceof FastbootError);
    assert.equal((err as FastbootError).reason, "unknown variable battery-soc-ok");
    return true;
  });
});

test("client: injected Nth-flash failure stops with verbatim reason; earlier flashes persisted", async () => {
  const device = new SimulatedDevice({
    initiallyUnlocked: true,
    injection: { kind: "failNthFlash", nth: 3, reason: "partition table does not support vbmeta" },
  });
  const client = new FastbootClient(device);

  await client.flash("avb_custom_key", bytes(64, 1));
  await client.flash("boot", bytes(64, 2));
  await assert.rejects(client.flash("vbmeta", bytes(64, 3)), (err: unknown) => {
    assert.ok(err instanceof FastbootError);
    assert.equal(
      (err as FastbootError).reason,
      "partition table does not support vbmeta",
    );
    return true;
  });

  assert.equal(device.partitions.has("avb_custom_key"), true);
  assert.equal(device.partitions.has("boot"), true);
  assert.equal(device.partitions.has("vbmeta"), false); // stopped before write
});

test("client: erase, flashing unlock/lock, reboot scripted transitions", async () => {
  const device = new SimulatedDevice();
  const client = new FastbootClient(device);

  assert.equal(device.unlocked, false);
  await client.flashingUnlock();
  assert.equal(device.unlocked, true);
  await client.flashingLock();
  assert.equal(device.unlocked, false);

  device.partitions.set("boot", bytes(16, 7));
  await client.erase("boot");
  assert.equal(device.partitions.has("boot"), false);

  await client.reboot();
  await client.reboot("bootloader");
});

test("client: refuseUnlock injection surfaces bootloader reason verbatim", async () => {
  const device = new SimulatedDevice({
    injection: { kind: "refuseUnlock", reason: "oem unlock is not allowed" },
  });
  const client = new FastbootClient(device);
  await assert.rejects(client.flashingUnlock(), (err: unknown) => {
    assert.ok(err instanceof FastbootError);
    assert.equal((err as FastbootError).reason, "oem unlock is not allowed");
    return true;
  });
  assert.equal(device.unlocked, false);
});

test("client: wrongProduct simulation is visible via getvar gate", async () => {
  const device = new SimulatedDevice({ vars: { product: "panther" } });
  const client = new FastbootClient(device);
  const product = await client.getvar("product");
  assert.notEqual(product, "tokay"); // installer step-5 gate must stop here
  assert.equal(product, "panther");
});

test("client: raw image larger than max-download-size is refused (H2 — no silent split)", async () => {
  const device = new SimulatedDevice({
    initiallyUnlocked: true,
    vars: { "max-download-size": "1024" },
  });
  const client = new FastbootClient(device);
  const image = bytes(2560, 0x5a);
  await assert.rejects(
    client.flash("system", image, { maxDownloadSize: 1024 }),
    (err: unknown) => {
      assert.ok(err instanceof ProtocolError);
      assert.match((err as ProtocolError).message, /cannot flash safely/u);
      return true;
    },
  );
  assert.equal(device.partitions.size, 0, "refuse happens before any transfer");
});

// --- sparse.ts ---------------------------------------------------------------

interface SparseChunkSpec {
  type: number;
  blocks?: number;
  fillWord?: number;
  data?: Uint8Array;
}

function buildSparse(blockSize: number, specs: SparseChunkSpec[]): Uint8Array {
  const chunkHeaderSize = 12;
  const parts: Uint8Array[] = [];
  for (const spec of specs) {
    const dataSize =
      spec.type === 0xcac2 ? 4 : spec.data !== undefined ? spec.data.length : 0;
    const header = new Uint8Array(chunkHeaderSize);
    const view = new DataView(header.buffer);
    view.setUint16(0, spec.type);
    view.setUint32(4, dataSize);
    if (spec.blocks !== undefined) {
      view.setUint32(8, spec.blocks);
    }
    parts.push(header);
    if (spec.data !== undefined) {
      parts.push(spec.data);
    }
    if (spec.type === 0xcac2 && spec.fillWord !== undefined) {
      const word = new Uint8Array(4);
      new DataView(word.buffer).setUint32(0, spec.fillWord);
      parts.push(word);
    }
  }
  const totalBlocks = specs.reduce(
    (sum, s) => sum + (s.blocks ?? (s.data?.length ?? 0) / blockSize),
    0,
  );
  const header = new Uint8Array(28);
  const view = new DataView(header.buffer);
  view.setUint32(0, SPARSE_MAGIC);
  view.setUint16(4, 1);
  view.setUint16(6, 0);
  view.setUint16(8, 28);
  view.setUint16(10, chunkHeaderSize);
  view.setUint32(12, blockSize);
  view.setUint32(16, totalBlocks);
  view.setUint32(20, specs.length);
  return concat(header, ...parts);
}

test("sparse: hand-built fixture splits RAW/FILL/DONT_CARE correctly", () => {
  const blockSize = 4096;
  const rawA = bytes(blockSize * 2, 0x11);
  const rawB = bytes(blockSize, 0x22);
  const image = buildSparse(blockSize, [
    { type: 0xcac1, data: rawA },
    { type: 0xcac2, blocks: 2, fillWord: 0xdeadbeef },
    { type: 0xcac3 },
    { type: 0xcac1, data: rawB },
  ]);

  assert.equal(isSparseImage(image), true);
  const header = parseSparseHeader(image);
  assert.equal(header.blockSize, blockSize);
  assert.equal(header.totalChunks, 4);

  const chunks = sparseChunks(image);
  assert.equal(chunks.length, 4);
  assert.equal(chunks[0]?.type, "RAW");
  assert.deepEqual(chunks[0]?.data, rawA);
  assert.equal(chunks[1]?.type, "FILL");
  assert.equal(chunks[1]?.outputSize, blockSize * 2);
  assert.deepEqual(chunks[1]?.data, repeatFill(0xdeadbeef, blockSize * 2));
  assert.equal(chunks[2]?.type, "DONT_CARE");
  assert.equal(chunks[2]?.data.length, 0);
  assert.equal(chunks[3]?.type, "RAW");
  assert.deepEqual(chunks[3]?.data, rawB);
});

test("sparse: passthrough for raw images", () => {
  const raw = bytes(1024, 0x77);
  assert.equal(isSparseImage(raw), false);
  const chunks = imageDownloadChunks(raw);
  assert.equal(chunks.length, 1);
  assert.deepEqual(chunks[0], raw);
});

test("sparse: expanded chunk concatenation reproduces physical image layout", () => {
  const blockSize = 512;
  const raw = bytes(blockSize, 0x33);
  const image = buildSparse(blockSize, [
    { type: 0xcac2, blocks: 1, fillWord: 0x01020304 },
    { type: 0xcac1, data: raw },
    { type: 0xcac3 },
  ]);
  const expanded = concat(...imageDownloadChunks(image));
  const expected = new Uint8Array(blockSize * 2);
  expected.fill(0);
  // The FILL chunk expands to the repeated dword across the whole block.
  const view = new DataView(expected.buffer);
  for (let off = 0; off + 4 <= blockSize; off += 4) {
    view.setUint32(off, 0x01020304);
  }
  expected.set(raw, blockSize);
  assert.deepEqual([...expanded], [...expected], "expanded output must equal physical layout");
  // And the FILL chunk itself must be the repeated dword.
  assert.deepEqual(
    [...imageDownloadChunks(image)[0]!],
    [...repeatFill(0x01020304, blockSize)],
  );
});

test("sparse: rejects bad magic and truncated chunks", () => {
  assert.throws(() => parseSparseHeader(bytes(28, 0)), SparseError);
  const good = buildSparse(4096, [{ type: 0xcac1, data: bytes(4096, 1) }]);
  const truncated = good.subarray(0, 30);
  assert.throws(() => sparseChunks(truncated), SparseError);
});

// --- usb.ts (mocked USBDevice, no hardware) ----------------------------------

/** Reply factory returning a REAL DataView over a fresh buffer, like WebUSB does. */
type ReplyFactory = () => Uint8Array | Error;

class MockInEndpoint {
  private consumed = 0;
  constructor(private readonly replies: ReplyFactory[]) {}
  next(): Uint8Array | Error {
    const factory = this.replies[Math.min(this.consumed, this.replies.length - 1)];
    if (factory === undefined) {
      throw new Error("mock has no replies");
    }
    const reply = factory();
    this.consumed += 1;
    return reply;
  }
}

function mockUsbDevice(replies: ReplyFactory[]): {
  picker: UsbPicker;
  device: FastbootUsbDevice;
  written: Uint8Array[];
} {
  const written: Uint8Array[] = [];
  const endpoint = new MockInEndpoint(replies);
  const config: UsbConfigSnap = {
    configurationValue: 1,
    interfaces: [
      {
        interfaceNumber: 0,
        alternates: [
          {
            interfaceClass: 255,
            interfaceSubclass: 66,
            interfaceProtocol: 1,
            endpoints: [
              { direction: "in", type: "bulk", endpointNumber: 1 },
              { direction: "out", type: "bulk", endpointNumber: 1 },
            ],
          },
        ],
      },
    ],
  };
  const device: FastbootUsbDevice = {
    configurations: [config],
    open: async () => {},
    selectConfiguration: async () => {},
    claimInterface: async () => {},
    releaseInterface: async () => {},
    close: async () => {},
    transferOut: async (_endpoint, data) => {
      written.push(toBytesCopy(data));
      return { status: "ok" };
    },
    transferIn: async (_endpoint, _length, options) => {
      if (options?.signal?.aborted) {
        throw new DOMException("The transfer was aborted", "AbortError");
      }
      const reply = endpoint.next();
      if (reply instanceof Error) {
        throw reply;
      }
      // Real WebUSB hands back a DataView over its own buffer.
      const owned = reply.slice().buffer.slice(reply.byteOffset, reply.byteOffset + reply.byteLength);
      return { status: "ok", data: new DataView(owned as ArrayBuffer) };
    },
  };
  const picker: UsbPicker = { requestDevice: async () => device };
  return { picker, device, written };
}

function toBytesCopy(data: BufferSource): Uint8Array {
  if (data instanceof Uint8Array) {
    return data.slice();
  }
  return new Uint8Array(data as ArrayBuffer).slice();
}

test("usb: transport round-trips a getvar over mocked USBDevice", async () => {
  const { picker, written } = mockUsbDevice([() => encodeCommand("OKAYtokay")]);
  const transport = await webUsbTransport(picker);
  const client = new FastbootClient(transport);
  assert.equal(await client.getvar("product"), "tokay");
  assert.deepEqual(written[0], encodeCommand("getvar:product"));
  assert.equal(PACKET_SIZE, 512);
  await transport.close();
});

test("usb: AbortSignal forwarded into transferIn aborts the read", async () => {
  let observedSignal: AbortSignal | undefined;
  const { picker } = mockUsbDevice([
    () => {
      throw new Error("should not be reached when pre-aborted");
    },
  ]);
  // Wrap the mock so the test can observe the forwarded signal.
  const originalRequest = picker.requestDevice.bind(picker);
  picker.requestDevice = async (options) => {
    const dev = await originalRequest(options);
    const innerTransferIn = dev.transferIn.bind(dev);
    const wrappedTransferIn = async (endpoint: number, length: number, opts?: { signal?: AbortSignal }) =>
      innerTransferIn(endpoint, length, opts);
    dev.transferIn = wrappedTransferIn;
    return dev;
  };
  void observedSignal;

  const controller = new AbortController();
  controller.abort(); // pre-abort: WebUSB would reject immediately
  const transport = await webUsbTransport(picker, { signal: controller.signal });
  await assert.rejects(transport.readPacket(), (err: unknown) => {
    assert.ok(err instanceof Error);
    assert.match(err.message, /aborted/);
    return true;
  });
});

test("usb: classifyTransferError maps DOMException names explicitly", () => {
  const aborted = classifyTransferError(new DOMException("x", "AbortError"));
  assert.match(aborted.message, /aborted/);
  const gone = classifyTransferError(new DOMException("y", "NotFoundError"));
  assert.match(gone.message, /disappeared/);
  const plain = classifyTransferError(new Error("plain"));
  assert.equal(plain.message, "plain");
});

test("usb: requestFastbootDevice classifies NotFoundError picker rejection", async () => {
  const picker: UsbPicker = {
    requestDevice: async () => {
      throw new DOMException("user cancelled chooser", "NotFoundError");
    },
  };
  await assert.rejects(requestFastbootDevice(picker), (err: unknown) => {
    assert.ok(err instanceof Error);
    assert.match(err.message, /No device was selected/);
    return true;
  });
});

test("usb: failed claim closes the opened device instead of leaking it", async () => {
  let closed = false;
  const config: UsbConfigSnap = { configurationValue: 1, interfaces: [] };
  const device: FastbootUsbDevice = {
    configurations: [config],
    open: async () => {},
    selectConfiguration: async () => {},
    claimInterface: async () => {
      throw new Error("claim busy");
    },
    releaseInterface: async () => {},
    close: async () => {
      closed = true;
    },
    transferOut: async () => ({ status: "ok" }),
    transferIn: async () => ({ status: "ok" }),
  };
  const picker: UsbPicker = { requestDevice: async () => device };
  await assert.rejects(webUsbTransport(picker), /Could not claim|No fastboot interface/);
  assert.equal(closed, true);
});

// --- Phase-5 E1: H1/H2/H3 transport fixes --------------------------------------

/** Transport wrapper queueing scripted extra packets before each device read. */
class ScriptedPacketDevice {
  readonly inner: SimulatedDevice;
  private script: string[][] = [];
  constructor(inner: SimulatedDevice) {
    this.inner = inner;
  }
  /** Queue packets to emit BEFORE the next readPacket call (in order). */
  queueBeforeNextRead(packets: string[]): void {
    this.script.push(packets);
  }
  async send(command: string): Promise<void> {
    await this.inner.send(command);
  }
  async readPacket(): Promise<Uint8Array> {
    const extra = this.script.shift() ?? [];
    this.inner.queueAheadForTests(extra.map((packet) => encodeCommand(packet)));
    return this.inner.readPacket();
  }
  async transfer(data: Uint8Array): Promise<void> {
    await this.inner.transfer(data);
  }
}

function repeatFillBytes(word: number, length: number): Uint8Array {
  const out = new Uint8Array(length);
  const view = new DataView(out.buffer);
  for (let off = 0; off + 4 <= length; off += 4) {
    view.setUint32(off, word);
  }
  return out;
}

test("H1: client.flash fetches getvar:max-download-size itself when no budget supplied", async () => {
  const device = new SimulatedDevice({
    initiallyUnlocked: true,
    vars: { "max-download-size": "1024" },
  });
  const log = collectingLog();
  const client = new FastbootClient(device, log);
  const image = bytes(512, 0x5a);

  // No options.maxDownloadSize at all — the client must ask THE DEVICE.
  await client.flash("system", image);

  assert.ok(log.lines.includes("> getvar:max-download-size"));
  assert.ok(log.lines.includes("< OKAY1024"));
  assert.deepEqual([...device.partitions.get("system")!], [...image]);
});

test("H1: missing max-download-size variable stops BEFORE any transfer with stated reason", async () => {
  const device = new SimulatedDevice({ initiallyUnlocked: true });
  device.forgetVar("max-download-size");
  const log = collectingLog();
  const client = new FastbootClient(device, log);

  await assert.rejects(
    client.flash("system", bytes(64, 1)),
    (err: unknown) => {
      assert.ok(err instanceof ProtocolError);
      assert.match(err.message, /max-download-size/u);
      assert.match(err.message, /refusing to flash without a known budget/u);
      return true;
    },
  );
  assert.equal(device.partitions.size, 0, "nothing may be written");
  assert.equal(log.lines.filter((l) => l.startsWith("> download:")).length, 0);
});

test("H1: unusable max-download-size values stop before any download", async () => {
  for (const garbage of ["banana", "0"]) {
    const device = new SimulatedDevice({
      initiallyUnlocked: true,
      vars: { "max-download-size": garbage },
    });
    const log = collectingLog();
    const client = new FastbootClient(device, log);
    await assert.rejects(client.flash("system", bytes(64, 1)), ProtocolError);
    assert.equal(log.lines.filter((l) => l.startsWith("> download:")).length, 0, garbage);
    assert.equal(device.partitions.size, 0, garbage);
  }
});

test("H2 policy: raw image larger than budget is refused BEFORE any transfer", () => {
  const image = bytes(8192, 0x42);
  assert.throws(() => imageTransferUnits(image, 4096), (err: unknown) => {
    assert.ok(err instanceof ProtocolError);
    assert.match(err.message, /cannot flash safely/u);
    return true;
  });
  assert.equal(imageTransferUnits(image, 8192).length, 1);
});

test("H2 policy: single expanded sparse chunk over budget refuses; fitting chunks pack greedily", () => {
  const oversized = buildSparse(4096, [{ type: 0xcac1, data: bytes(8192, 0x11) }]);
  assert.throws(() => imageTransferUnits(oversized, 4096), (err: unknown) => {
    assert.ok(err instanceof ProtocolError);
    assert.ok(err.message.startsWith(OVERSIZE_IMAGE_MESSAGE));
    return true;
  });

  const fits = buildSparse(4096, [
    { type: 0xcac2, blocks: 1, fillWord: 0xdeadbeef },
    { type: 0xcac1, data: bytes(4096, 0x22) },
  ]);
  const units = imageTransferUnits(fits, 4096);
  assert.equal(units.length, 2, "FILL block and RAW chunk stay separate units");
  const packed = concat(...units);
  const expected = concat(repeatFillBytes(0xdeadbeef, 4096), bytes(4096, 0x22));
  assert.deepEqual([...packed], [...expected]);
});

test("H2 policy: DONT_CARE/CRC32 layouts are refused outright (expansion cannot honour skip/verify)", () => {
  const layout = buildSparse(512, [
    { type: 0xcac1, data: bytes(512, 0x33) },
    { type: 0xcac3 },
  ]);
  assert.throws(() => imageTransferUnits(layout, 4096), (err: unknown) => {
    assert.ok(err instanceof ProtocolError);
    assert.match(err.message, /DONT_CARE\/CRC32/u);
    return true;
  });
});

test("H2 end-to-end: expanded sparse chunks stream as consecutive download+flash rounds on ONE partition", async () => {
  const device = new SimulatedDevice({
    initiallyUnlocked: true,
    vars: { "max-download-size": "4096" },
  });
  const log = collectingLog();
  const client = new FastbootClient(device, log);

  const blockA = bytes(4096, 0x11);
  const fillBlock = repeatFillBytes(0xefefefef, 4096);
  const blockB = bytes(4096, 0x22);
  const sparse = buildSparse(4096, [
    { type: 0xcac1, data: blockA },
    { type: 0xcac2, blocks: 1, fillWord: 0xefefefef },
    { type: 0xcac1, data: blockB },
  ]);

  await client.flash("system", sparse, { maxDownloadSize: 4096 });

  const stored = device.partitions.get("system");
  assert.ok(stored !== undefined, "partition must be written");
  assert.equal(stored.length, 12288, "simulator appends consecutive flash rounds");
  assert.deepEqual([...stored.slice(0, 4096)], [...blockA]);
  assert.deepEqual([...stored.slice(4096, 8192)], [...fillBlock]);
  assert.deepEqual([...stored.slice(8192)], [...blockB]);

  assert.deepEqual(
    log.lines.filter((l) => l.startsWith("> flash:")),
    ["> flash:system", "> flash:system", "> flash:system"],
    "each budget-sized unit is a download+flash pair on the SAME partition",
  );
  assert.equal(
    log.lines.filter((l) => l.startsWith("> download:")).length,
    3,
    "one download round per budget-sized unit",
  );
});

test("H2 regression: oversize abort leaves the device completely untouched", async () => {
  const device = new SimulatedDevice({ initiallyUnlocked: true });
  const log = collectingLog();
  const client = new FastbootClient(device, log);
  await assert.rejects(
    client.flash("system", buildSparse(4096, [{ type: 0xcac1, data: bytes(8192, 0x44) }]), {
      maxDownloadSize: 4096,
    }),
    ProtocolError,
  );
  assert.equal(device.partitions.size, 0);
  assert.equal(log.lines.filter((l) => l.startsWith("> download:")).length, 0);
  assert.equal(log.lines.filter((l) => l.startsWith("> flash:")).length, 0);
});

test("H2: zero/negative/non-integer budgets are unusable everywhere", () => {
  const image = bytes(16, 1);
  for (const bad of [0, -1024, 1.5]) {
    assert.throws(() => imageTransferUnits(image, bad), ProtocolError);
  }
});

test("H3: INFO lines before DATA after download: are logged verbatim and drained", async () => {
  const device = new SimulatedDevice({ initiallyUnlocked: true });
  const scripted = new ScriptedPacketDevice(device);
  scripted.queueBeforeNextRead(["INFOdownloading 'system'..."]);
  const log = collectingLog();
  const client = new FastbootClient(scripted, log);

  await client.flash("system", bytes(512, 0x77), { maxDownloadSize: 4096 });
  assert.ok(log.lines.includes("< INFOdownloading 'system'..."), "INFO reaches console verbatim");
  assert.deepEqual([...device.partitions.get("system")!], [...bytes(512, 0x77)]);
});

test("H3: INFO lines before OKAY after flash: are drained too", async () => {
  const device = new SimulatedDevice({ initiallyUnlocked: true });
  const scripted = new ScriptedPacketDevice(device);
  // download: → DATA, payload transfer → OKAY, flash: → INFO then OKAY.
  scripted.queueBeforeNextRead([]);
  scripted.queueBeforeNextRead([]);
  scripted.queueBeforeNextRead(["INFOwriting 'system' partition..."]);
  const log = collectingLog();
  const client = new FastbootClient(scripted, log);

  await client.flash("system", bytes(512, 0x77), { maxDownloadSize: 4096 });
  assert.ok(log.lines.includes("< INFOwriting 'system' partition..."));
  assert.deepEqual([...device.partitions.get("system")!], [...bytes(512, 0x77)]);
});

test("H3: FAIL still fails fast even when INFO traffic precedes it", async () => {
  const device = new SimulatedDevice({ initiallyUnlocked: true });
  const scripted = new ScriptedPacketDevice(device);
  scripted.queueBeforeNextRead([]);
  scripted.queueBeforeNextRead([]);
  scripted.queueBeforeNextRead(["INFOchecking 'system'...", "FAILimage too large for partition"]);
  const log = collectingLog();
  const client = new FastbootClient(scripted, log);

  await assert.rejects(
    client.flash("system", bytes(512, 0x77), { maxDownloadSize: 4096 }),
    (err: unknown) => {
      assert.ok(err instanceof FastbootError);
      assert.equal((err as FastbootError).reason, "image too large for partition");
      return true;
    },
  );
  assert.ok(log.lines.includes("< INFOchecking 'system'..."), "preceding INFO stays visible");
  assert.ok(log.lines.includes("< FAILimage too large for partition"));
  assert.equal(
    log.lines.filter((l) => l.startsWith("> flash:")).length,
    1,
    "FAIL aborts — no further flash commands",
  );
});

test("M1-adjacent: DATA size mismatch carries announced size verbatim as FastbootError", async () => {
  class WrongDataDevice extends ScriptedPacketDevice {
    private injected: Uint8Array | null = null;
    injectOnce(packet: string): void {
      this.injected = encodeCommand(packet);
    }
    override async readPacket(): Promise<Uint8Array> {
      if (this.injected !== null) {
        const packet = this.injected;
        this.injected = null;
        return packet;
      }
      return super.readPacket();
    }
  }
  const device = new SimulatedDevice({ initiallyUnlocked: true });
  const weird = new WrongDataDevice(device);
  weird.injectOnce("DATA00000200"); // device announces 512 of the requested 4096
  const client = new FastbootClient(weird);

  await assert.rejects(
    client.flash("system", bytes(4096, 0x88), { maxDownloadSize: 4096 }),
    (err: unknown) => {
      assert.ok(err instanceof FastbootError);
      assert.match((err as FastbootError).reason, /DATA size mismatch/u);
      assert.match((err as FastbootError).reason, /accepted 512/u);
      return true;
    },
  );
  assert.equal(device.partitions.size, 0);
});

// --- helpers -----------------------------------------------------------------

function bytes(length: number, pattern: number): Uint8Array {
  const out = new Uint8Array(length);
  out.fill(pattern % 256);
  return out;
}

function repeatFill(word: number, length: number): Uint8Array {
  const out = new Uint8Array(length);
  const view = new DataView(out.buffer);
  for (let off = 0; off + 4 <= length; off += 4) {
    view.setUint32(off, word);
  }
  return out;
}

function concat(...parts: Uint8Array[]): Uint8Array {
  const total = parts.reduce((n, p) => n + p.length, 0);
  const out = new Uint8Array(total);
  let off = 0;
  for (const part of parts) {
    out.set(part, off);
    off += part.length;
  }
  return out;
}
