/**
 * Type declarations for the readiness gate (T-WEBINSTALL-FLASHALL-READINESS-GATE).
 */
import type { FlashMatrix } from "./gen-flash-matrix.mjs";

export interface GateClause {
  id: string;
  description: string;
  ok: boolean;
  detail: string;
}

export interface GateResult {
  pass: boolean;
  clauses: GateClause[];
}

export declare function evaluateGate(
  /** `null` is accepted and FAILS CLOSED (clause 1: matrix-present). */
  matrix: Record<string, unknown> | FlashMatrix | null,
  options?: {
    allowedProducts?: string[];
    /** Probe a different tree (drills + tests). Defaults to INSTALLER_ROOT. */
    installerRoot?: string;
    /** Where `<product>-latest` pointers live. Defaults to the repo releases dir. */
    releasesDir?: string;
    /** Parsed anchor pins (trust-anchor clause injection point). */
    pins?: unknown;
    /** Path to docs/expected-anchors.json. */
    anchorsPath?: string;
  },
): GateResult;

export declare function runGate(argv: string[]): number;

export declare const DEFAULT_MATRIX: string;
export declare const STATUS_PATH: string;
export declare const DEFAULT_RELEASES_DIR: string;
export { buildMatrix } from "./gen-flash-matrix.mjs";
export type { FlashMatrix };
