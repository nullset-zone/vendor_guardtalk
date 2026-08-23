/**
 * Claim linter (build gate). Scans files for FORBIDDEN patterns; exit
 * non-zero with file:line report on any hit. Security language passes ONLY
 * when the line names the mechanism that backs it.
 */
import { readFileSync } from "node:fs";

export interface LintHit {
  readonly file: string;
  readonly line: number;
  readonly text: string;
  readonly rule: string;
  readonly excerpt: string;
}

const EXCERPT_MAX = 120;

const OTA_PATTERNS: RegExp[] = [
  /automatic update/i,
  /over[- ]the[- ]air/i,
  /\bOTA\b/,
  /we'?ll push/i,
  /remote update/i,
];

const SUPERLATIVE_PATTERNS: RegExp[] = [/\binstall now\b/i, /\bone-click\b/i, /\beasy\b/i];

const SECURITY_ADJ_PATTERNS: RegExp[] = [/\bsecure\b/i, /\bsafe\b/i, /\bprotected\b/i, /\bprotection\b/i];

const MECHANISM_ALLOWLIST: RegExp[] = [
  /verified boot/i,
  /\bAVB\b/,
  /user.?s key/i,
  /your key/i,
  /signature/i,
  /signed/i,
  /hash comparison/i,
  /hash match/i,
  /digest/i,
  /\bGateway\b/,
  /air.?gap/i,
  /fingerprint/i,
  /offline/i,
  /no network/i,
  /zero network/i,
];

const AUTO_ADVANCE_PATTERNS: RegExp[] = [
  /setInterval\s*\(/,
  /setTimeout\s*\([^)]*,\s*[^)]*\)\s*;?\s*\/\/\s*(advance|next|step)/i,
];

const GENERATE_FLOW_IN_UPDATE_PATTERNS: RegExp[] = [/generate(-| )?(a )?key/i, /generateKey/i];

const SUCCESS_BEFORE_FINGERPRINT_PATTERNS: RegExp[] =
  [/success/i];

export interface LintOptions {
  /** Route bundle identity of each file, e.g. "update" | "other". */
  route?: string;
  /** Disable individual rule families (used by focused tests). */
  skip?: ReadonlyArray<"auto-advance" | "generate-in-update" | "success-order">;
}

export function lintText(text: string, file: string, options: LintOptions = {}): LintHit[] {
  const hits: LintHit[] = [];
  const lines = text.split(/\r?\n/);
  for (let index = 0; index < lines.length; index += 1) {
    const line = lines[index] ?? "";
    const lineNumber = index + 1;
    for (const pattern of OTA_PATTERNS) {
      if (pattern.test(line)) {
        hits.push({ file, line: lineNumber, text: line, rule: "no-ota-language", excerpt: excerptOf(line) });
      }
    }
    for (const pattern of SUPERLATIVE_PATTERNS) {
      if (pattern.test(line)) {
        hits.push({ file, line: lineNumber, text: line, rule: "no-superlatives", excerpt: excerptOf(line) });
      }
    }
    for (const pattern of SECURITY_ADJ_PATTERNS) {
      if (!pattern.test(line)) {
        continue;
      }
      const mechanism = MECHANISM_ALLOWLIST.some((m) => m.test(line));
      if (!mechanism) {
        hits.push({
          file,
          line: lineNumber,
          text: line,
          rule: "security-word-requires-mechanism",
          excerpt: excerptOf(line),
        });
      }
    }
    const skip = options.skip ?? [];
    if (!skip.includes("auto-advance") && AUTO_ADVANCE_PATTERNS.some((p) => p.test(line))) {
      hits.push({ file, line: lineNumber, text: line, rule: "no-auto-advance", excerpt: excerptOf(line) });
    }
    if (
      !skip.includes("generate-in-update") &&
      options.route === "update" &&
      GENERATE_FLOW_IN_UPDATE_PATTERNS.some((p) => p.test(line))
    ) {
      hits.push({
        file,
        line: lineNumber,
        text: line,
        rule: "no-generate-flow-on-update",
        excerpt: excerptOf(line),
      });
    }
    if (
      !skip.includes("success-order") &&
      SUCCESS_BEFORE_FINGERPRINT_PATTERNS.some((p) => p.test(line)) &&
      !/(fingerprint|compare|comparison|match)/i.test(line)
    ) {
      hits.push({
        file,
        line: lineNumber,
        text: line,
        rule: "no-success-before-fingerprint-compare",
        excerpt: excerptOf(line),
      });
    }
  }
  return hits;
}

export function lintFiles(paths: readonly string[], options: LintOptions = {}): LintHit[] {
  const hits: LintHit[] = [];
  for (const path of paths) {
    let text: string;
    try {
      text = readFileSync(path, "utf8");
    } catch {
      hits.push({ file: path, line: 0, text: "", rule: "unreadable-file", excerpt: "" });
      continue;
    }
    hits.push(...lintText(text, path, options));
  }
  return hits;
}

export function formatHits(hits: readonly LintHit[]): string {
  if (hits.length === 0) {
    return "claim lint: clean";
  }
  return hits
    .map((hit) => `${hit.file}:${hit.line} [${hit.rule}] ${hit.excerpt}`)
    .join("\n");
}

/** CLI entry: `tsx lib/claims/lint-claims.ts file1 file2 ...` */
export function main(argv: readonly string[]): number {
  const args = argv.filter((arg) => !arg.startsWith("--"));
  if (args.length === 0) {
    process.stderr.write("usage: tsx lib/claims/lint-claims.ts <file> [...]\n");
    return 2;
  }
  const routeArg = argv.find((arg) => arg.startsWith("--route="));
  const hits = lintFiles(args, routeArg === undefined ? {} : { route: routeArg.slice("--route=".length) });
  if (hits.length > 0) {
    process.stderr.write(`${formatHits(hits)}\n`);
    return 1;
  }
  process.stdout.write("claim lint: clean\n");
  return 0;
}

function excerptOf(line: string): string {
  const trimmed = line.trim();
  return trimmed.length > EXCERPT_MAX ? `${trimmed.slice(0, EXCERPT_MAX - 3)}...` : trimmed;
}

if (process.argv[1] !== undefined && import.meta.url.endsWith(process.argv[1].replace(/\\/g, "/").split("/").pop() ?? "")) {
  process.exit(main(process.argv.slice(2)));
}
