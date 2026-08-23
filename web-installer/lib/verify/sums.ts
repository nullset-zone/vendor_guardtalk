/** Strict SHA256SUMS parsing: `<64hex> [ *]<filename>` lines, line-numbered errors. */
import { bytesToHex, normalizeSha256 } from "../../src/hash.js";

const LINE_RE = /^([0-9A-Fa-f]{64}) ([ *]?)(.+)$/;
const SAFE_NAME_RE = /^[A-Za-z0-9._-]+$/;
const SECRET_NAME_RE = /\.(pem|pk8)$/i;
const MAX_EXCERPT = 60;

export class SumsParseError extends Error {
  readonly line: number;

  constructor(line: number, detail: string) {
    super(line === 0 ? `SHA256SUMS: ${detail}` : `SHA256SUMS line ${line}: ${detail}`);
    this.name = "SumsParseError";
    this.line = line;
  }
}

export interface Sha256SumsEntry {
  readonly filename: string;
  readonly digest: string;
  readonly binaryMarker: boolean;
  readonly line: number;
}

export class Sha256Sums {
  readonly #byName: ReadonlyMap<string, Sha256SumsEntry>;

  constructor(entries: readonly Sha256SumsEntry[]) {
    this.#byName = new Map(entries.map((entry) => [entry.filename, entry]));
  }

  get size(): number {
    return this.#byName.size;
  }

  entries(): Sha256SumsEntry[] {
    return [...this.#byName.values()];
  }

  lookup(filename: string): Sha256SumsEntry | undefined {
    return this.#byName.get(filename);
  }

  digestFor(filename: string): string | undefined {
    return this.#byName.get(filename)?.digest;
  }
}

export function parseSha256Sums(text: string): Sha256Sums {
  const entries: Sha256SumsEntry[] = [];
  const firstLineByName = new Map<string, number>();
  const withoutBom = text.startsWith("\uFEFF") ? text.slice(1) : text;
  const lines = withoutBom.split(/\r?\n/);
  for (let index = 0; index < lines.length; index += 1) {
    const raw = lines[index] ?? "";
    const line = raw.replace(/\r$/, "");
    if (line.trim() === "" || line.startsWith("#")) {
      continue;
    }
    const lineNumber = index + 1;
    const match = LINE_RE.exec(line);
    if (match === null) {
      throw new SumsParseError(lineNumber, `malformed line: "${excerpt(line)}"`);
    }
    const digest = normalizeSha256(match[1] ?? "");
    const binaryMarker = (match[2] ?? "") === "*";
    const filename = (match[3] ?? "").trim();
    if (filename.length === 0 || !SAFE_NAME_RE.test(filename) || filename.includes("..")) {
      throw new SumsParseError(lineNumber, `refusing filename: "${excerpt(filename)}"`);
    }
    if (SECRET_NAME_RE.test(filename)) {
      throw new SumsParseError(lineNumber, `key material file must never be listed: ${filename}`);
    }
    const firstLine = firstLineByName.get(filename);
    if (firstLine !== undefined) {
      throw new SumsParseError(lineNumber, `duplicate entry for ${filename} (first on line ${firstLine})`);
    }
    firstLineByName.set(filename, lineNumber);
    entries.push({ filename, digest, binaryMarker, line: lineNumber });
  }
  if (entries.length === 0) {
    throw new SumsParseError(0, "lists no files");
  }
  return new Sha256Sums(entries);
}

/** Case-insensitive SHA-256 hex comparison; false when either side is not valid hex. */
export function hexEqual(a: string, b: string): boolean {
  try {
    return normalizeSha256(a) === normalizeSha256(b);
  } catch {
    return false;
  }
}

export { bytesToHex };

function excerpt(text: string): string {
  return text.length > MAX_EXCERPT ? `${text.slice(0, MAX_EXCERPT - 3)}...` : text;
}
