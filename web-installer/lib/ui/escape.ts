/** Minimal HTML escaping for template-built markup. Attributes are always
 * double-quoted, so apostrophes pass through verbatim (exact-label rule);
 * no inline handlers or style attributes are ever emitted. */

const ESCAPES: Readonly<Record<string, string>> = {
  "&": "&amp;",
  "<": "&lt;",
  ">": "&gt;",
  '"': "&quot;",
};

export function escapeHtml(text: string): string {
  let out = "";
  for (const ch of text) {
    const escaped = ESCAPES[ch];
    out += escaped === undefined ? ch : escaped;
  }
  return out;
}
