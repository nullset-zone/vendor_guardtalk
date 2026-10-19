/**
 * Claim linter (build gate). Scans files for FORBIDDEN patterns; exit
 * non-zero with file:line report on any hit. Security language passes ONLY
 * when the line names the mechanism that backs it.
 */
import { readFileSync } from "node:fs";
import { resolveReadinessVerdict } from "./readiness-verdict.js";

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

/**
 * Boot-readiness overclaim family. The programme is BOOT_VERIFIED=false and
 * "a host check is not a device proof" (ruling R5): a line that asserts a
 * specific stamp/build/device boots, or that it is positively boot-verified,
 * is an overclaim. A disclaimer on the same line (`not`, `unverified`,
 * `never`, `without`, `no`, `cannot`) is the honest form and passes.
 */
const BOOT_OVERCLAIM_PATTERNS: RegExp[] = [
  /\bBOOT_VERIFIED\s*(?:=|:)\s*true\b/i,
  /\bboot[- ]verified\b/i,
  /\bverified to boot\b/i,
  /\bproven to boot\b/i,
  /\bguaranteed to boot\b/i,
  /\bthis (?:stamp|build|bundle|device) (?:will )?boots?\b/i,
];

const BOOT_DISCLAIMER_PATTERNS: RegExp[] = [
  /\bunverified\b/i,
  /\bun-verified\b/i,
  /\bnot\b/i,
  /\bnever\b/i,
  /\bwithout\b/i,
  /\bno\b/i,
  /\bcannot\b/i,
  /\bcan'?t\b/i,
];

/**
 * Radio/RIL/telephony-excision overclaim family. The programme verdict is
 * `radio = FALSE` at runtime — the baseband and modem kernel transport remain
 * as Tier B/C residuals — so an unqualified absolute that the radio/RIL/modem
 * surface is "fully excised"/"removed"/"gone"/"purged"/..., or that `radio.img`
 * is "fully removed", is an overclaim.
 *
 * Hardening (T-EXCISE-CLAIMS-LINTER-RADIO-HARDENING): the previous gate was
 * `any qualifier word anywhere on the line disarms the rule` — fail-open, so an
 * honest scope word (`runtime`, `verdict`, `host`, `no`, `residual`, `Tier`)
 * could name-drop an absolute claim into silence (H1). A qualifier now
 * suppresses ONLY when it is ATTACHED to the excision predicate (e.g.
 * `userspace is excised`, `HAL is removed`, `not fully excised`) or states a
 * contradiction/residual (`still ships`, `verdict remains FALSE`, `Tier B`).
 * The verb set is generalised (H2), sentence-split/long-gap structures are
 * matched (H3), and objects that are not the modem function (`radio buttons`,
 * `radio.img partition`, `radio firmware files`, `telephony permission
 * requests`, ...) are excluded as non-functional contexts (H4). Like every
 * family here this is a mechanical tripwire, not a correctness or boot proof.
 */
const RADIO_NOUN_SOURCE = "radio(?:\\.img)?|ril|modem|telephony|cellular|baseband";

/**
 * Verbs/phrases that assert the excision happened. Each use site requires a
 * whitespace character immediately before the predicate so hyphenated labels
 * (`radio-excised.mk`, `apps-excised.mk`) are never matched.
 */
const RADIO_EXCISION_PREDICATE_SOURCE = [
  "excised",
  "removed",
  "stripped",
  "eliminated",
  "deleted",
  "purged",
  "neutrali[sz]ed",
  "wiped",
  "erased",
  "nuked",
  "eradicated",
  "zeroed",
  "expunged",
  "obliterated",
  "scrapped",
  "dismantled",
  "disabled",
  "killed",
  "gone",
  "off\\s+for\\s+good",
  "no\\s+longer\\s+(?:exists?|present|available|supported|shipped|in\\s+the\\s+build)",
  "done\\s+away\\s+with",
  "cleaned\\s+out",
  "surgically\\s+removed",
].join("|");

/** Absolute modifiers that make an excision claim unqualified. */
const RADIO_ABSOLUTE_SOURCE =
  "fully|completely|entirely|totally|wholly|utterly|thoroughly|permanently|100\\s*%|for\\s+good";

const RADIO_EXCISION_OVERCLAIM_PATTERNS: RegExp[] = [
  // Noun-first, same sentence: radio noun → [absolute] predicate within 100 chars.
  new RegExp(
    `\\b(?:${RADIO_NOUN_SOURCE})\\b[^.;\\n]{0,100}\\s(?:${RADIO_ABSOLUTE_SOURCE}\\s+)?(?:${RADIO_EXCISION_PREDICATE_SOURCE})\\b`,
    "i",
  ),
  // Absolute-first, same sentence: [absolute] predicate → radio noun.
  new RegExp(
    `\\b(?:${RADIO_ABSOLUTE_SOURCE})\\s+(?:${RADIO_EXCISION_PREDICATE_SOURCE})\\b[^.;\\n]{0,100}\\b(?:${RADIO_NOUN_SOURCE})\\b`,
    "i",
  ),
  // Sentence-split / long gap: radio noun → (crossing `.` or `;`, ≤80 chars) →
  // absolute predicate. Catches `Radio and modem. Fully excised.` (H3).
  new RegExp(
    `\\b(?:${RADIO_NOUN_SOURCE})\\b[^\\n]{0,80}?(?:${RADIO_ABSOLUTE_SOURCE})\\s+(?:${RADIO_EXCISION_PREDICATE_SOURCE})\\b`,
    "i",
  ),
  // The radio.img build artifact is explicitly removed.
  /\bradio\.img\b[^.;\n]{0,30}?(?:fully\s+)?removed\b/i,
];

/**
 * Genuine qualifiers — a scope word suppresses only when it ATTACHES to the
 * excision predicate, or the line states a contradiction/residual. Bare
 * co-occurrence (`runtime`, `verdict`, `host`, `no`, `residual`, `Tier`) is
 * deliberately NOT enough (H1). `HAL` carries the `i` flag like every other
 * entry (H5).
 */
const RADIO_EXCISION_QUALIFIER_PATTERNS: RegExp[] = [
  // Scoped object governs the excision predicate: "userspace is excised",
  // "HAL is removed", "host-side ... excised", "*userspace* is excised".
  new RegExp(
    `\\b(?:userspace|host-side|host\\s+side|HAL)\\b[^\\w\\n]{0,8}(?:(?:is|are|was|were|has\\s+been|have\\s+been|be|been)\\s+)?(?:${RADIO_ABSOLUTE_SOURCE}\\s+)?(?:${RADIO_EXCISION_PREDICATE_SOURCE})\\b`,
    "i",
  ),
  // Negation attached to the predicate: "not fully excised", "never removed".
  new RegExp(
    `\\b(?:not|never|without|isn'?t|aren'?t|wasn'?t|weren'?t|cannot|can'?t)\\b[^\\n]{0,20}?(?:${RADIO_ABSOLUTE_SOURCE}\\s+)?(?:${RADIO_EXCISION_PREDICATE_SOURCE})\\b`,
    "i",
  ),
  // Contradiction / residual markers.
  /\bstill\s+ships?\b/i,
  /\bresidual\b/i,
  /\bTier[-\s]?[ABC]\b/i,
  /\bremains\s+(?:false|unverified|unchanged|in\s+place)\b/i,
  /\bverdict\b[^.;\n]{0,30}?\b(?:false|remains|unchanged|unverified)\b/i,
  /\bruntime\b[^.;\n]{0,30}?\b(?:verdict|false|remains|unchanged)\b/i,
];

/**
 * Non-functional contexts (H4): UI widgets, build artifacts, permission
 * surfaces and calibration data. These name a `radio|cellular|telephony` token
 * but not the modem excision this rule guards. Every entry is multi-token so a
 * lone innocent word cannot disarm the rule; these do not name the modem
 * verdict, so appending one to a genuine overclaim does not read as scope.
 */
const RADIO_NON_FUNCTION_CONTEXT_PATTERNS: RegExp[] = [
  /\bradio\s+buttons?\b/i,
  /\b(?:radio|cellular|signal|telephony)\s+(?:status\s+)?icons?\b/i,
  /\bradio\s+calibration(?:\s+data)?\b/i,
  /\b(?:radio|telephony)\s+permission(?:s|\s+requests?)?\b/i,
  /\bradio\s+firmware\s+files?\b/i,
  /\bradio\.img\s+partition\b/i,
];

/**
 * Readiness-claim family (F-WEBINSTALL-FLASHALL-CLAIM-LINT, D-015).
 *
 * The programme's honesty state today: `status.json` is `alpha`/`preLaunch`
 * with `flashCapability.liveFlashClaimed:false`, only 2 of 4 advertised
 * products have a packed channel, and the packed channels point at a JULY
 * stamp while live stamps are September. Any user-visible copy that asserts the
 * installer is "ready"/"production ready" or that it can flash "every available
 * image"/"all images" is therefore an overclaim.
 *
 * Unlike every other family here, this one is NOT disarmed by a same-line token.
 * Its ONLY suppression is a whole-run readiness verdict of PASS
 * (`LintOptions.readinessReady === true`), supplied by the caller — the
 * readiness gate reads the same shipped facts. This asymmetry is deliberate
 * (D-016): the OPEN card `T-EXCISE-CLAIMS-LINTER-ALLOWLIST-LAUNDERING` shows a
 * same-line allow-list is a laundering primitive, so this family has none.
 *
 * Scope note: verbs are anchored to the SUBJECT the programme can actually
 * claim — "this installer" / "the installer" / "GuardTalkOS" / "every/all
 * image(s)" / "every available image". A bare adjective about unrelated UI
 * (e.g. "the phone is ready to unlock") is not matched, keeping the family
 * precise enough to be non-vacuous without being a blanket word ban.
 */
const READINESS_SUBJECT_SOURCE =
  "this\\s+installer|the\\s+installer|the\\s+web\\s+installer|guardtalk\\s*os|guardtalkos|this\\s+page|this\\s+site";

/**
 * A negated readiness predicate is the HONEST form and must never bite. The
 * negation is part of the match (`!` in the regex), not a same-line allow-list:
 * the pattern simply does not match when the predicate is negated. This keeps
 * the family allow-list-free (D-016) while avoiding the honesty-statement false
 * positive (`... does not report PASS, so no page may claim X is ready`).
 */
const NOT_NEGATED = "(?<!\\bnot\\s)(?<!\\bnever\\s)(?<!\\bno\\s)(?<!\\bisn'?t\\s)(?<!\\baren'?t\\s)(?<!\\bcannot\\s)(?<!\\bcan'?t\\s)";

const READINESS_CLAIM_PATTERNS: RegExp[] = [
  // "<subject> is/are ready" — with an optional "now"/"finally"/"fully".
  new RegExp(
    `${NOT_NEGATED}\\b(?:${READINESS_SUBJECT_SOURCE})\\b[^.;\\n]{0,60}?\\b(?:is|are|was|were)\\s+(?:not\\s+|never\\s+)?(?:now\\s+|finally\\s+|fully\\s+)?ready\\b`,
    "i",
  ),
  // "production ready" / "production-ready" — the phrase itself is the claim.
  /\bproduction[-\s]?ready\b/i,
  // "<subject> is ready for production|to flash|to ship".
  new RegExp(
    `\\b(?:${READINESS_SUBJECT_SOURCE})\\b[^.;\\n]{0,60}?\\bready\\s+(?:for\\s+production|to\\s+(?:flash|ship|release|deploy))\\b`,
    "i",
  ),
  // "ready to flash every|all ... image(s)".
  /\bready\s+to\s+flash\s+(?:every|all)\b/i,
  // "flash every available image" / "flash all images".
  /\bflash\s+(?:every|all)\s+(?:available\s+)?images?\b/i,
  /\b(?:every|all)\s+(?:available\s+)?images?\s+(?:is|are)\s+(?:flashable|ready|installable|available)\b/i,
  // "every available image can be flashed" / "all images can now be flashed".
  /\b(?:every|all)\s+(?:available\s+)?images?\s+can\s+(?:now\s+)?be\s+flashed\b/i,
  // "ready to flash everything".
  /\bready\s+to\s+flash\s+everything\b/i,
  // Direct "image(s) ready to flash" predicate.
  /\bimages?\s+(?:are|is)\s+ready\s+to\s+be\s+flashed\b/i,
];

export interface LintOptions {
  /** Route bundle identity of each file, e.g. "update" | "other". */
  route?: string;
  /** Disable individual rule families (used by focused tests). */
  skip?: ReadonlyArray<"auto-advance" | "generate-in-update" | "success-order">;
  /**
   * Whether the machine readiness verdict is currently PASS (D-015). The
   * `no-readiness-overclaim` family is suppressed ONLY when this is exactly
   * `true` — a whole-file/whole-run verdict, never a same-line token. Absent,
   * `false`, or any non-`true` value leaves the family armed (fail closed).
   */
  readinessReady?: boolean;
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
    if (
      BOOT_OVERCLAIM_PATTERNS.some((p) => p.test(line)) &&
      !BOOT_DISCLAIMER_PATTERNS.some((p) => p.test(line))
    ) {
      hits.push({
        file,
        line: lineNumber,
        text: line,
        rule: "no-boot-overclaim",
        excerpt: excerptOf(line),
      });
    }
    if (
      RADIO_EXCISION_OVERCLAIM_PATTERNS.some((p) => p.test(line)) &&
      !RADIO_EXCISION_QUALIFIER_PATTERNS.some((p) => p.test(line)) &&
      !RADIO_NON_FUNCTION_CONTEXT_PATTERNS.some((p) => p.test(line))
    ) {
      hits.push({
        file,
        line: lineNumber,
        text: line,
        rule: "no-radio-excision-overclaim",
        excerpt: excerptOf(line),
      });
    }
    // Readiness family (D-015): armed unless the whole-run verdict is PASS.
    // There is deliberately NO same-line escape — see READINESS_CLAIM_PATTERNS.
    if (
      options.readinessReady !== true &&
      READINESS_CLAIM_PATTERNS.some((p) => p.test(line))
    ) {
      hits.push({
        file,
        line: lineNumber,
        text: line,
        rule: "no-readiness-overclaim",
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

/** CLI entry: `tsx lib/claims/lint-claims.ts [--route=X] [--readiness-verdict=PATH] <file> [...]` */
export function main(argv: readonly string[]): number {
  const args = argv.filter((arg) => !arg.startsWith("--"));
  if (args.length === 0) {
    process.stderr.write(
      "usage: tsx lib/claims/lint-claims.ts [--route=X] [--readiness-verdict=PATH] <file> [...]\n",
    );
    return 2;
  }
  const routeArg = argv.find((arg) => arg.startsWith("--route="));
  const verdictArg = argv.find((arg) => arg.startsWith("--readiness-verdict="));
  // D-015: the readiness family is armed unless the verdict is a positive PASS.
  // The verdict comes from the readiness gate (explicit file) or is derived
  // from the shipped facts. Either way the linter and the gate read the same
  // source, and an unknowable verdict is FAIL.
  const verdict = resolveReadinessVerdict(
    verdictArg === undefined ? undefined : verdictArg.slice("--readiness-verdict=".length),
  );
  const hits = lintFiles(args, {
    ...(routeArg === undefined ? {} : { route: routeArg.slice("--route=".length) }),
    readinessReady: verdict.ready,
  });
  if (hits.length > 0) {
    process.stderr.write(`${formatHits(hits)}\n`);
    return 1;
  }
  process.stdout.write(
    `claim lint: clean (readiness verdict: ${verdict.ready ? "PASS" : "NOT READY"} via ${verdict.source})\n`,
  );
  return 0;
}

function excerptOf(line: string): string {
  const trimmed = line.trim();
  return trimmed.length > EXCERPT_MAX ? `${trimmed.slice(0, EXCERPT_MAX - 3)}...` : trimmed;
}

if (process.argv[1] !== undefined && import.meta.url.endsWith(process.argv[1].replace(/\\/g, "/").split("/").pop() ?? "")) {
  process.exit(main(process.argv.slice(2)));
}
