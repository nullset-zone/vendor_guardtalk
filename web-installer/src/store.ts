import { ChannelError } from "./errors.js";
import type { ArtifactStore } from "./types.js";

export class MemoryArtifactStore implements ArtifactStore {
  constructor(private readonly blobs: ReadonlyMap<string, Uint8Array>) {}

  async read(name: string): Promise<Uint8Array> {
    const data = this.blobs.get(name);
    if (data === undefined) {
      throw new ChannelError(`artifact not in store: ${name}`);
    }
    return data;
  }
}
