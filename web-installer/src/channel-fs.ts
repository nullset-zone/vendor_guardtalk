import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { loadChannelFromTexts, verifyChannelAvbKey } from "./channel.js";
import type { ChannelBundle } from "./types.js";

/** Host-only. The wizard uses `loadChannelFromTexts` instead. */
export async function loadChannelFromDir(dir: string): Promise<ChannelBundle> {
  const [manifestJson, sha256sums, filesTxt, avbBytes] = await Promise.all([
    readFile(join(dir, "manifest.json"), "utf8"),
    readFile(join(dir, "SHA256SUMS"), "utf8"),
    readFile(join(dir, "files.txt"), "utf8"),
    readFile(join(dir, "avb_pkmd.bin")),
  ]);
  const bundle = loadChannelFromTexts({ manifestJson, sha256sums, filesTxt });
  verifyChannelAvbKey(
    bundle,
    new Uint8Array(avbBytes.buffer, avbBytes.byteOffset, avbBytes.byteLength),
  );
  return bundle;
}
