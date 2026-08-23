import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { loadChannelFromTexts } from "./channel.js";
import type { ChannelBundle } from "./types.js";

/** Host-only. The wizard uses `loadChannelFromTexts` instead. */
export async function loadChannelFromDir(dir: string): Promise<ChannelBundle> {
  const [manifestJson, sha256sums, filesTxt] = await Promise.all([
    readFile(join(dir, "manifest.json"), "utf8"),
    readFile(join(dir, "SHA256SUMS"), "utf8"),
    readFile(join(dir, "files.txt"), "utf8"),
  ]);
  return loadChannelFromTexts({ manifestJson, sha256sums, filesTxt });
}
