/** Production release origin (HTTPS-only; no cleartext LAN HTTP origin). */
export const RELEASE_FETCH_ORIGIN = "https://releases.guardtalk.io";

/** Exact CSP meta string. connect-src is strictly 'self' (no cleartext http:// origin). */
export const INSTALLER_CSP =
  "default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src 'self'";

export function cspMetaTag(): string {
  return `<meta http-equiv="Content-Security-Policy" content="${INSTALLER_CSP}">`;
}
