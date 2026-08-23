/** Channel + plan types. Channel is tokay|akita / dev/unlocked (DEC-007/010). */

export const ALLOWED_PRODUCTS = ["tokay", "akita"] as const;
export type AllowedProduct = (typeof ALLOWED_PRODUCTS)[number];
/** Default advertised product (Pixel 9). */
export const ALLOWED_PRODUCT: AllowedProduct = "tokay";
export const FLASH_ORDER = ["firmware", "avb_custom_key", "os"] as const;
export const ARTIFACT_PHASES = ["firmware", "avb", "os"] as const;
export type FlashOrderPhase = (typeof FLASH_ORDER)[number];
export type ArtifactPhase = (typeof ARTIFACT_PHASES)[number];

export interface ChannelArtifact {
  name: string;
  phase: ArtifactPhase;
  sha256: string;
  size: number;
}

export interface ChannelAvb {
  publicKeyFile: "avb_pkmd.bin";
  sha256: string;
  size: number;
}

export interface ChannelSignature {
  required: boolean;
  mode: "hash-only" | "openssh-signify";
  file: string | null;
  allowedSigners: string | null;
  note?: string;
}

export interface ChannelManifest {
  schemaVersion: 1;
  product: string;
  advertisedDevices: string[];
  reservedProducts?: string[];
  channel: string;
  bootState: string;
  channelLabel: string;
  verifiedBootClaim: string;
  releaseId: string;
  unixEpoch: number;
  sourceStamp: string;
  flashOrder: string[];
  factoryZip: string | null;
  factoryZipFollowOn?: string;
  avb: ChannelAvb;
  artifacts: ChannelArtifact[];
  signature: ChannelSignature;
}

export interface FileListEntry {
  name: string;
  phase: ArtifactPhase;
  size: number;
}

export interface ChannelBundle {
  manifest: ChannelManifest;
  sha256sums: ReadonlyMap<string, string>;
  files: FileListEntry[];
}

export interface ArtifactStore {
  read(name: string): Promise<Uint8Array>;
}

export type ReconnectHook = () => Promise<void>;

export interface CommandResult {
  ok: boolean;
  text?: string;
}

export interface FlashOptions {
  slot?: "other";
}

export interface FastbootTransport {
  /**
   * DEC-009 dry-run marker. Missing or false means live: execute/lock HOLD.
   */
  readonly dryRun?: boolean;
  connect(): Promise<void>;
  getVar(name: string): Promise<string>;
  runCommand(command: string): Promise<CommandResult>;
  flash(
    partition: string,
    data: Uint8Array,
    options?: FlashOptions,
  ): Promise<void>;
  rebootBootloader(onReconnect: ReconnectHook): Promise<void>;
}

export function isDryRunTransport(transport: FastbootTransport): boolean {
  return transport.dryRun === true;
}

export type PlanStep =
  | {
      kind: "flash";
      phase: FlashOrderPhase;
      artifact: string;
      partition: string;
      slot?: "other";
    }
  | { kind: "erase"; phase: FlashOrderPhase; partition: string }
  | { kind: "command"; phase: FlashOrderPhase; command: string }
  | { kind: "reconnect"; phase: FlashOrderPhase; reason: string };

export interface FlashPlan {
  product: AllowedProduct;
  flashOrder: readonly FlashOrderPhase[];
  steps: PlanStep[];
}

/** Host/unit tests never perform or claim a live device flash. */
export const LIVE_FLASH_CLAIMED = false;
