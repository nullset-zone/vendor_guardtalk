/**
 * Type declarations for the INVENTORY matrix generator (T-WEBINSTALL-FLASHALL-INVENTORY).
 * Kept deliberately small: only the surface the tests consume.
 */

export declare const INSTALLER_ROOT: string;
export declare const REPO_ROOT: string;
/**
 * The desktop-flash release store. Honours `GUARDTALK_RELEASES_ROOT`; falls back
 * to `<repo>/releases/desktop-flash`. Lets a standalone checkout point at an
 * external store instead of deriving it from the Android repo layout.
 */
export declare const RELEASES_ROOT: string;
export declare const FLASH_ORDER: readonly ["firmware", "avb_custom_key", "os"];
export declare const ARTIFACT_PHASES: readonly ["firmware", "avb", "os"];
export declare const FLASH_STEP: number;
export declare const STEP_TITLES: readonly string[];

export type ArtifactPhase = "firmware" | "avb" | "os";

export interface MatrixArtifact {
  name: string;
  filesTxtPhase: ArtifactPhase;
  declaredPhase: ArtifactPhase | null;
  phaseMatches: boolean;
  flashStep: number;
  flashOrderPhase: string;
  size: number;
  sha256: string | null;
  inManifest: boolean;
}

export interface MatrixChannel {
  channel: string;
  channelLabel: string;
  bootState: string;
  verifiedBootClaim: string;
  releaseId: string;
  unixEpoch: number;
  sourceStamp: string;
  sourceStampIsCurrent: boolean;
  advertisedCurrentStamp: string | null;
  artifactCount: number;
  phaseCounts: Record<ArtifactPhase, number>;
  unmappedArtifacts: string[];
  artifacts: MatrixArtifact[];
}

export interface MatrixDevice {
  product: string;
  advertised: {
    inAllowlist: boolean;
    inTargets: boolean;
    inExperimental: boolean;
    absentFromProductFacts: boolean;
  };
  packed: boolean;
  packedDir: string | null;
  packedIncomplete: boolean;
  currentStamp: string | null;
  stampsOnDisk: string[];
  channels: MatrixChannel[];
}

export interface DivergenceRow {
  product: string;
  advertisedBy: string[];
  inAllowlist: boolean;
  inTargets: boolean;
  inExperimental: boolean;
  packed: boolean;
  packedDir: string | null;
  packedSourceStamp: string | null;
  advertisedCurrentStamp: string | null;
  latestPointer: string | null;
  verdict: string;
  reason: string;
  absentFromProductFacts: boolean;
}

export interface FlashMatrix {
  $comment: string;
  schemaVersion: number;
  generatedAt: string;
  generationCommand: string;
  revision: string;
  honesty: { bootVerified: boolean; liveFlashClaimed: boolean | null; note: string };
  counts: {
    allowlist: number;
    statusTargets: number;
    statusExperimentalTargets: number;
    packedChannels: number;
    advertisedNotPacked: number;
  };
  sources: {
    allowlist: { path: string; line: number; products: string[] };
    productFacts: { path: string; targets: string[]; experimentalTargets: string[] };
    channelsRoot: string;
    stampsRoot: string;
  };
  phases: readonly string[];
  flashOrder: readonly string[];
  flashStep: { step: number; title: string };
  devices: MatrixDevice[];
  divergence: DivergenceRow[];
  summary: { packedDevices: string[]; advertisedNotPacked: string[]; staleChannels: string[] };
}

export declare function phaseForArtifact(name: string): ArtifactPhase | null;
export declare function readAllowedProducts(): { products: string[]; sourceLine: number };
export declare function readStatusTargets(): {
  targets: string[];
  experimentalTargets: string[];
  liveFlashClaimed: boolean | null;
  path: string;
};
export declare function readStamps(releasesDir: string): {
  stamps: { product: string; stamp: string; dir: string }[];
  pointers: Map<string, { name: string; target: string | null }>;
};
export declare function buildMatrix(input: {
  generatedAt: string;
  generationCommand: string;
  revision: string;
}): FlashMatrix;
export declare function renderMarkdown(matrix: FlashMatrix): string;
