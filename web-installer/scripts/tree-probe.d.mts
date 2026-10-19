/**
 * Type declarations for the live tree probe
 * (T-WEBINSTALL-READINESS-GATE-TREE-BINDING).
 *
 * These helpers only READ the filesystem: `channels/<product>/` and
 * `releases/desktop-flash/`. They never decide freshness — see
 * `scripts/channel-freshness.mjs` for the one implementation of that rule.
 */

export declare const REQUIRED_CHANNEL_FILES: readonly string[];

export interface TreeRoots {
  installerRoot: string;
  channelsRoot: string;
  releasesDir: string;
}

export interface ChannelProbe {
  product: string;
  dir: string;
  exists: boolean;
  packed: boolean;
  requiredFiles: string[];
  /** Every required file that is absent (the full set when the dir is absent). */
  missingFiles: string[];
  /** Alias of `missingFiles`, kept for readability at call sites. */
  missingRequired: string[];
  manifest: Record<string, unknown> | null;
  manifestError: string | null;
}

export interface LatestPointer {
  name: string;
  present: boolean;
  isSymlink: boolean;
  target: string | null;
  targetExists: boolean;
  error: string | null;
}

export interface ManifestClaim {
  ok: boolean;
  sourceStamp: string | null;
  releaseId: string | null;
  unixEpoch: number | null;
  error: string | null;
}

export interface FileIdentity {
  /** The symlink target as written on disk, or null for a regular file. */
  link: string | null;
  dev: number;
  ino: number;
  size: number;
  mtimeMs: number;
}

export declare function makeRoots(installerRoot: string, releasesDir: string): TreeRoots;
export declare function probeChannel(roots: TreeRoots, product: string): ChannelProbe;
export declare function resolveLatestPointer(roots: TreeRoots, product: string): LatestPointer;
export declare function listStampsOnDisk(roots: TreeRoots, product?: string | null): string[];
export declare function listChannelDirs(roots: TreeRoots): string[];
export declare function readManifestClaim(probe: ChannelProbe): ManifestClaim;
export declare function fileIdentity(path: string): FileIdentity | null;
