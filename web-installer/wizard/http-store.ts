import { ChannelError } from "../src/errors.js";
import type { ArtifactStore } from "../src/types.js";

const SAFE_NAME = /^[A-Za-z0-9._-]+$/;

/** Fetch one artifact at a time from the hosted channel directory. */
export class HttpArtifactStore implements ArtifactStore {
  constructor(private readonly baseUrl: string) {}

  async read(name: string): Promise<Uint8Array> {
    if (!SAFE_NAME.test(name) || name.includes("..")) {
      throw new ChannelError(`refusing artifact name: ${name}`);
    }
    const url = `${this.baseUrl}${name}`;
    const response = await fetch(url);
    if (!response.ok) {
      throw new ChannelError(`artifact not on server: ${name}`);
    }
    return new Uint8Array(await response.arrayBuffer());
  }
}
