/** Lab origin for the narrowed D-006 connect-src. One host, one port, never a wildcard. */
export const RELEASE_FETCH_ORIGIN = "http://192.168.2.220:9100";

/** Exact CSP meta string. connect-src names RELEASE_FETCH_ORIGIN and no other source. */
export const INSTALLER_CSP =
  `default-src 'none'; script-src 'self'; style-src 'self'; img-src 'self' data:; connect-src ${RELEASE_FETCH_ORIGIN}`;

export function cspMetaTag(): string {
  return `<meta http-equiv="Content-Security-Policy" content="${INSTALLER_CSP}">`;
}
