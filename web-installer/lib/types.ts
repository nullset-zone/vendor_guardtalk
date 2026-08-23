/** Shared types for the web-installer lib tree. */

/**
 * Verbatim mono-console sink. Every fastboot command and response must pass
 * through one of these (PLAN §0 lib/fastboot, step-6 console requirement).
 * Implementations render to the UI console; tests capture strings.
 */
export type ConsoleLog = (line: string) => void;

export function collectingLog(): ConsoleLog & { lines: string[] } {
  const lines: string[] = [];
  const sink = (line: string): void => {
    lines.push(line);
  };
  return Object.assign(sink, { lines });
}
