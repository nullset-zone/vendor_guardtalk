/**
 * Type declarations for the channel freshness invariant
 * (T-WEBINSTALL-FLASHALL-FRESHNESS).
 */

export interface ParsedStamp {
  product: string;
  releaseId: string;
  unixEpoch: number;
}

export interface FreshnessInput {
  sourceStamp: string;
  releaseId: string;
  unixEpoch: number;
  currentStamp: string | null;
  stampsOnDisk: readonly string[];
}

export interface FreshnessClause {
  id: string;
  ok: boolean;
  detail: string;
}

export interface FreshnessResult {
  fresh: boolean;
  product: string;
  clauses: FreshnessClause[];
}

export declare function parseStamp(stamp: string): ParsedStamp | null;
export declare function checkChannelFreshness(
  product: string,
  input: FreshnessInput,
): FreshnessResult;
export declare function freshnessClause(results: readonly FreshnessResult[]): {
  id: string;
  description: string;
  ok: boolean;
  detail: string;
};
