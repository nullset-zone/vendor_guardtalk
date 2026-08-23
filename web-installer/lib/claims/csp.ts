/** Exact CSP meta string per D-006 — zero network access at runtime. */

export const INSTALLER_CSP =
  "default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'none'";

export function cspMetaTag(): string {
  return `<meta http-equiv="Content-Security-Policy" content="${INSTALLER_CSP}">`;
}
