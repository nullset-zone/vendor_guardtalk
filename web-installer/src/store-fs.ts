import { readFile } from "node:fs/promises";
import { join } from "node:path";
import { ChannelError } from "./errors.js";
import type { ArtifactStore } from "./types.js";

/** Host-only. The wizard uses `MemoryArtifactStore`. */
export function createFsArtifactStore(dir: string): ArtifactStore {
  return {
    async read(name: string): Promise<Uint8Array> {
      if (name.includes("/") || name.includes("\\") || name.includes("..")) {
        throw new ChannelError(`refusing path-like artifact name: ${name}`);
      }
      return new Uint8Array(await readFile(join(dir, name)));
    },
  };
}
