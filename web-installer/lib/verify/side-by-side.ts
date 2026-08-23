/**
 * SideBySide comparison model + mono-safe formatters.
 * Rendered everywhere comparisons happen: hash compare, fingerprint compare,
 * device product compare. Pure; no DOM.
 */

export interface SideBySide {
  readonly expected: string;
  readonly actual: string;
  readonly match: boolean;
}

/** Case-insensitive hex compare (SHA-256 digests, fingerprints). */
export function compareHex(expected: string, actual: string): SideBySide {
  return {
    expected: normalizeWhitespace(expected),
    actual: normalizeWhitespace(actual),
    match: expected.trim().toLowerCase() === actual.trim().toLowerCase(),
  };
}

export function compareExact(expected: string, actual: string): SideBySide {
  return { expected, actual, match: expected === actual };
}

const HEX_RE = /^[0-9a-f]+$/i;

function normalizeWhitespace(value: string): string {
  return value.trim().toLowerCase();
}

/**
 * Two aligned rows of fixed-width cells. Long values are truncated symmetric
 * around their centre so leading/trailing digits stay visible in narrow mono
 * columns; a `…` marks each truncation.
 */
export function formatSideBySide(
  label: string,
  side: SideBySide,
  cellWidth = 32,
): string {
  const verdict = side.match ? "MATCH" : "MISMATCH";
  const header = `${label.padEnd(12)} ${verdict}`;
  return [header, `expected ${truncateMiddle(side.expected, cellWidth)}`, `actual   ${truncateMiddle(side.actual, cellWidth)}`].join("\n");
}

export function isHexValue(value: string): boolean {
  return HEX_RE.test(value.trim());
}

export function truncateMiddle(value: string, maxWidth: number): string {
  if (value.length <= maxWidth) {
    return value;
  }
  const keep = Math.max(1, Math.floor((maxWidth - 1) / 2));
  return `${value.slice(0, keep)}\u2026${value.slice(value.length - keep)}`;
}

/** Verdict word only — never colour-dependent; callers add the chip word. */
export function verdictWord(side: SideBySide): "MATCH" | "MISMATCH" {
  return side.match ? "MATCH" : "MISMATCH";
}
