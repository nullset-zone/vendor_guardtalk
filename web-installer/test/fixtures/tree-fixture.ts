/**
 * T-WEBINSTALL-READINESS-GATE-TREE-BINDING — fixture builder.
 *
 * Builds a THROWAWAY flash tree in `os.tmpdir()` shaped exactly like the real
 * one, so the readiness gate can be drilled against the filesystem:
 *
 *   <root>/docs/flash-matrix.json
 *   <root>/channels/<product>/{manifest.json,files.txt,SHA256SUMS,avb_pkmd.bin,<artifact>.img}
 *   <root>/releases/desktop-flash/<product>-YYYYMMDD-HHMMSS/<artifact>.img
 *   <root>/releases/desktop-flash/<product>-latest -> <product>-YYYYMMDD-HHMMSS
 *
 * WHY GENERATED AND NOT CHECKED IN: the real tree's artifacts are hundreds of
 * megabytes of symlinked image blobs. A fixture tree only needs the SHAPE the
 * gate reasons about (dirs, four required files, a manifest claim, a pointer,
 * stamp dirs), so it is written on the fly into a temp dir that is removed
 * afterwards. Nothing here can ever touch the real `channels/` or
 * `releases/desktop-flash/` — every path is under `os.tmpdir()`.
 *
 * The channel artifacts are SYMLINKS into the fixture's own stamp dir, matching
 * how the real packer lays them out (`channels/<p>/boot.img ->
 * releases/desktop-flash/<stamp>/boot.img`) while keeping the fixture small.
 *
 * HONESTY: the fixture proves GATE BEHAVIOUR, never that an image boots.
 */
import { createHash } from "node:crypto";
import { existsSync, mkdirSync, readFileSync, rmSync, symlinkSync, writeFileSync } from "node:fs";
import { mkdtempSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";

/** A minimal but well-formed matrix: schemaVersion 1, devices, divergence. */
export interface FixtureMatrix {
  schemaVersion: number;
  honesty: { bootVerified: boolean; liveFlashClaimed: boolean };
  counts: { packedChannels: number; advertisedNotPacked: number };
  devices: FixtureDevice[];
  divergence: unknown[];
  summary: { packedDevices: string[]; advertisedNotPacked: string[]; staleChannels: string[] };
}

export interface FixtureDevice {
  product: string;
  packed: boolean;
  packedDir: string | null;
  currentStamp: string | null;
  stampsOnDisk: string[];
  channels: FixtureChannel[];
}

export interface FixtureChannel {
  channel: string;
  releaseId: string;
  unixEpoch: number;
  sourceStamp: string;
  artifacts: {
    name: string;
    filesTxtPhase: string;
    phaseMatches: boolean;
    inManifest: boolean;
    size: number;
  }[];
  unmappedArtifacts: string[];
}

/** Artifacts every fixture channel ships: one per phase. */
export const FIXTURE_ARTIFACTS: { name: string; phase: "firmware" | "avb" | "os" }[] = [
  { name: "bootloader.img", phase: "firmware" },
  { name: "avb_pkmd.bin", phase: "avb" },
  { name: "boot.img", phase: "os" },
];

/** `<product>-YYYYMMDD-HHMMSS` stamps used by the fixtures. */
export const FIXTURE_STAMPS = {
  current: {
    tokay: "tokay-20260928-084839",
    akita: "akita-20260928-083403",
    komodo: "komodo-20260928-052609",
    rango: "rango-20260928-081134",
  },
  stale: {
    tokay: "tokay-20260725-102506",
    akita: "akita-20260725-101434",
    komodo: "komodo-20260915-063833",
    rango: "rango-20260725-133716",
  },
} as const;

/**
 * Every product the LIVE `src/types.ts` ALLOWED_PRODUCTS advertises. The gate
 * reads that allowlist from the real source tree even when probing a fixture
 * tree (it is the advertised set, not a tree fact), so a fixture must cover all
 * four or clause 2 fails for reasons unrelated to the drill.
 */
export const FIXTURE_PRODUCTS: readonly string[] = ["tokay", "akita", "komodo", "rango"];

/**
 * The one pkmd body every fixture channel ships. The real tree ships the SAME
 * public key in all four channels, so a single pin covers them; the fixture
 * mirrors that so the gate's trust-anchor clause behaves as it does live.
 */
export const FIXTURE_PKMD_TEXT = "fixture avb_pkmd.bin (shared by every fixture channel)\n";

function sha256(text: string): string {
  return createHash("sha256").update(text).digest("hex");
}

/** The out-of-band pin document shape (`docs/expected-anchors.json`). */
export interface PinDoc {
  $comment?: string;
  schemaVersion: string;
  channel: string;
  anchors: Record<
    string,
    { file: string; sha256: string; size: number; sourceStamp?: string; sourceStampSha256?: string }
  >;
}

/** Per-device artifact-set pin (T-WEBINSTALL-RANGO-ARTIFACT-SHAPE-DIVERGENCE). */
export interface ShapeDoc {
  $comment?: string;
  schemaVersion: string;
  channel: string;
  devices: Record<
    string,
    { sourceStamp: string | null; artifactCount: number; artifacts: string[] }
  >;
}

/** Fixture anchor bytes for `product` packed from `stamp` (one place, so bites stay honest). */
export function fixturePkmdBytes(product: string, stamp: string): string {
  return `fixture pkmd ${product}/${stamp}\n`;
}

/** Parse `YYYYMMDD-HHMMSS` out of a stamp name (fixture-sized, no validation). */
function tokenOf(stamp: string): string {
  const parts = stamp.split("-");
  return `${parts[1] ?? ""}-${parts[2] ?? ""}`;
}

function epochOf(stamp: string): number {
  const [, date = "", time = ""] = stamp.split("-");
  const n = (s: string, a: number, b: number): number => Number(s.slice(a, b));
  return (
    Date.UTC(
      n(date, 0, 4),
      n(date, 4, 6) - 1,
      n(date, 6, 8),
      n(time, 0, 2),
      n(time, 2, 4),
      n(time, 4, 6),
    ) / 1000
  );
}

export interface Writer {
  /** Write one stamp dir with its artifact blobs. */
  stamp(product: string, stamp: string): void;
  /**
   * Write a packed channel dir whose manifest CLAIMS `claimStamp`, with its
   * artifacts symlinked into a stamp dir (the stamp must already exist).
   */
  channel(product: string, claimStamp: string, linkStamp?: string): void;
  /** (Re)point `<product>-latest` at `target`. */
  pointer(product: string, target: string | null): void;
  /** Delete `<product>-latest`. */
  dropPointer(product: string): void;
  /** Delete the whole channel dir for `product`. */
  dropChannel(product: string): void;
  /** Remove one required file from a channel dir. */
  dropChannelFile(product: string, name: string): void;
  /** Rewrite docs/flash-matrix.json. */
  matrix(matrix: FixtureMatrix): void;
  /**
   * Write `docs/expected-anchors.json` pinning the anchors CURRENTLY on disk
   * (T-WEBINSTALL-TRUST-ANCHOR-VERIFICATION). A genuine tree calls this so the
   * `trust-anchor` clause has an out-of-band pin to compare against; a drill
   * that wants an "unpinned/barely-pinned" tree skips it or writes its own
   * document with `writeAnchors`. Returns the document that was written.
   */
  pins(products: readonly string[], channel?: string): PinDoc;
  /** Write an arbitrary pin document (or delete it with `null`). */
  writeAnchors(document: PinDoc | null): void;
  /**
   * Write `docs/expected-shape.json` pinning each channel's artifact set as it
   * currently is (T-WEBINSTALL-RANGO-ARTIFACT-SHAPE-DIVERGENCE). A genuine tree
   * calls this so the `channel-shape` clause has a per-device expectation; a
   * drill that wants an "unasserted shape" tree skips it (the clause then fails
   * closed, which is the intended behaviour).
   */
  shapes(products: readonly string[], channel?: string): ShapeDoc;
  /** Write an arbitrary shape document (or delete it with `null`). */
  writeShape(document: ShapeDoc | null): void;
  readonly root: string;
  readonly releasesDir: string;
  cleanup(): void;
}

/**
 * Create a throwaway tree. `products` are written with a CURRENT channel and a
 * resolved pointer unless `opts.packed` says otherwise.
 */
export function makeFixtureTree(
  dirPrefix = "gt-tree-",
): { writer: Writer; root: string; releasesDir: string } {
  const root = mkdtempSync(join(tmpdir(), dirPrefix));
  const releasesDir = join(root, "releases", "desktop-flash");
  mkdirSync(join(root, "docs"), { recursive: true });
  mkdirSync(join(root, "channels"), { recursive: true });
  mkdirSync(releasesDir, { recursive: true });

  const writer: Writer = {
    root,
    releasesDir,
    stamp(product, stamp) {
      const dir = join(releasesDir, stamp);
      mkdirSync(dir, { recursive: true });
      for (const artifact of FIXTURE_ARTIFACTS) {
        writeFileSync(join(dir, artifact.name), `fixture ${product}/${stamp}/${artifact.name}\n`);
      }
    },
    channel(product, claimStamp, linkStamp = claimStamp) {
      const dir = join(root, "channels", product);
      mkdirSync(dir, { recursive: true });
      const stampDir = join(releasesDir, linkStamp);
      for (const artifact of FIXTURE_ARTIFACTS) {
        // Re-writing a channel must be idempotent: repacking an existing tree
        // replaces the previous links, it does not fail on them.
        const artifactPath = join(dir, artifact.name);
        rmSync(artifactPath, { force: true });
        if (artifact.name === "avb_pkmd.bin") {
          // The real packer copies the public key IN (it is not a symlink).
          writeFileSync(artifactPath, FIXTURE_PKMD_TEXT);
          continue;
        }
        symlinkSync(join(stampDir, artifact.name), artifactPath);
      }
      const releaseId = tokenOf(claimStamp);
      const unixEpoch = epochOf(claimStamp);
      const pkmdText = FIXTURE_PKMD_TEXT;
      writeFileSync(
        join(dir, "manifest.json"),
        `${JSON.stringify(
          {
            channel: `${product}-dev`,
            channelLabel: `${product} (fixture)`,
            bootState: "unverified",
            verifiedBootClaim: false,
            releaseId,
            unixEpoch,
            sourceStamp: claimStamp,
            avb: {
              publicKeyFile: "avb_pkmd.bin",
              sha256: sha256(pkmdText),
              size: Buffer.byteLength(pkmdText),
            },
            artifacts: FIXTURE_ARTIFACTS.map((a) => ({ name: a.name })),
          },
          null,
          2,
        )}\n`,
      );
      writeFileSync(
        join(dir, "files.txt"),
        FIXTURE_ARTIFACTS.map(
          (a) => `${a.name} ${a.phase} ${String(Buffer.byteLength(`fixture ${product}/${linkStamp}/${a.name}\n`))}`,
        ).join("\n") + "\n",
      );
      writeFileSync(
        join(dir, "SHA256SUMS"),
        FIXTURE_ARTIFACTS.map(
          (a) => `${sha256(`fixture ${product}/${linkStamp}/${a.name}\n`)}  ${a.name}`,
        ).join("\n") + "\n",
      );
    },
    pointer(product, target) {
      const link = join(releasesDir, `${product}-latest`);
      rmSync(link, { recursive: true, force: true });
      if (target !== null) symlinkSync(target, link);
    },
    dropPointer(product) {
      rmSync(join(releasesDir, `${product}-latest`), { recursive: true, force: true });
    },
    dropChannel(product) {
      rmSync(join(root, "channels", product), { recursive: true, force: true });
    },
    dropChannelFile(product, name) {
      rmSync(join(root, "channels", product, name), { force: true });
    },
    matrix(matrix) {
      writeFileSync(join(root, "docs", "flash-matrix.json"), `${JSON.stringify(matrix, null, 2)}\n`);
    },
    /**
     * Pin the anchors CURRENTLY on disk. Reads each channel's avb_pkmd.bin so
     * the document is honest by construction (a later swap on disk then bites
     * the `trust-anchor` clause, which is exactly what those tests want).
     */
    pins(products: readonly string[], channel = "dev") {
      const anchors: PinDoc["anchors"] = {};
      for (const product of products) {
        const path = join(root, "channels", product, "avb_pkmd.bin");
        if (!existsSync(path)) continue;
        const bytes = readFileSync(path);
        anchors[product] = {
          file: "avb_pkmd.bin",
          sha256: createHash("sha256").update(bytes).digest("hex"),
          size: bytes.length,
        };
      }
      return {
        $comment: "FIXTURE pin file (never shipped). Test-only out-of-band AVB anchor codes.",
        schemaVersion: "expected-anchors/1",
        channel,
        anchors,
      };
    },
    writeAnchors(document) {
      const path = join(root, "docs", "expected-anchors.json");
      if (document === null) {
        rmSync(path, { force: true });
        return;
      }
      writeFileSync(path, `${JSON.stringify(document, null, 2)}\n`);
    },
    shapes(products, channel = "dev") {
      const devices: ShapeDoc["devices"] = {};
      for (const product of products) {
        const manifestPath = join(root, "channels", product, "manifest.json");
        if (!existsSync(manifestPath)) continue;
        const manifest = JSON.parse(readFileSync(manifestPath, "utf8")) as {
          artifacts?: { name?: string }[];
          sourceStamp?: string;
        };
        const artifacts = (manifest.artifacts ?? [])
          .map((a) => String(a?.name))
          .sort();
        devices[product] = {
          sourceStamp: manifest.sourceStamp ?? null,
          artifactCount: artifacts.length,
          artifacts,
        };
      }
      return {
        $comment: "FIXTURE shape file (never shipped). Test-only per-device artifact-set pins.",
        schemaVersion: "expected-shape/1",
        channel,
        devices,
      };
    },
    writeShape(document) {
      const path = join(root, "docs", "expected-shape.json");
      if (document === null) {
        rmSync(path, { force: true });
        return;
      }
      writeFileSync(path, `${JSON.stringify(document, null, 2)}\n`);
    },
    cleanup() {
      rmSync(root, { recursive: true, force: true });
    },
  };
  return { writer, root, releasesDir };
}

/**
 * A matrix that honestly describes `products`, all packed from their CURRENT
 * stamp. Mutate the returned object to build a lying matrix.
 */
export function honestMatrix(
  products: readonly string[],
  stamps: Record<string, string> = FIXTURE_STAMPS.current,
): FixtureMatrix {
  const devices = products.map((product): FixtureDevice => {
    const stamp = stamps[product] ?? "";
    return {
      product,
      packed: true,
      packedDir: `channels/${product}`,
      currentStamp: stamp,
      stampsOnDisk: [stamp],
      channels: [
        {
          channel: `${product}-dev`,
          releaseId: tokenOf(stamp),
          unixEpoch: epochOf(stamp),
          sourceStamp: stamp,
          artifacts: FIXTURE_ARTIFACTS.map((a) => ({
            name: a.name,
            filesTxtPhase: a.phase,
            phaseMatches: true,
            inManifest: true,
            size: 1,
          })),
          unmappedArtifacts: [],
        },
      ],
    };
  });
  return {
    schemaVersion: 1,
    honesty: { bootVerified: false, liveFlashClaimed: false },
    counts: { packedChannels: products.length, advertisedNotPacked: 0 },
    devices,
    divergence: [],
    summary: { packedDevices: [...products], advertisedNotPacked: [], staleChannels: [] },
  };
}

/**
 * Build a tree for `products`, all genuine: current channels, resolved pointers,
 * stamp dirs on disk. Returns the writer so a test can mutate one thing.
 */
export function genuineTree(products: readonly string[]): {
  writer: Writer;
  root: string;
  releasesDir: string;
  matrix: FixtureMatrix;
} {
  const { writer, root, releasesDir } = makeFixtureTree();
  const stamps: Record<string, string> = {};
  for (const product of products) {
    const stamp = FIXTURE_STAMPS.current[product as keyof typeof FIXTURE_STAMPS.current];
    stamps[product] = stamp;
    writer.stamp(product, stamp);
    writer.channel(product, stamp);
    writer.pointer(product, stamp);
  }
  const matrix = honestMatrix(products, stamps);
  writer.writeAnchors(writer.pins(products));
  writer.writeShape(writer.shapes(products));
  writer.matrix(matrix);
  return { writer, root, releasesDir, matrix };
}
