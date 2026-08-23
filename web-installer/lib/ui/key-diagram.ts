/**
 * Key-custody diagram (PLAN.md §5): a static, three-node inline SVG with
 * exact text labels and <title>+<desc> equivalents. No animation. The node
 * wordings are binding:
 *   1. "your private key — stays here"
 *   2. "your public key — goes into the phone"
 *   3. "GuardTalk's release key — proves the build, not the boot"
 */
import { escapeHtml } from "./escape.js";

const TITLE = "Key custody: which key goes where";
const DESC =
  "Three keys and where they live. Your private key stays on this computer. " +
  "Your public key goes into the phone and anchors verified boot there. " +
  "GuardTalk's release key only proves the build you downloaded; it never proves what boots.";

interface NodeSpec {
  readonly x: number;
  readonly y: number;
  readonly label: string;
}

const NODES: readonly NodeSpec[] = [
  { x: 150, y: 90, label: "your private key — stays here" },
  { x: 460, y: 90, label: "your public key — goes into the phone" },
  { x: 305, y: 210, label: "GuardTalk's release key — proves the build, not the boot" },
];

export const KEY_DIAGRAM_NODE_LABELS: readonly string[] = NODES.map((node) => node.label);

export function renderKeyDiagram(): string {
  const title = `<title>${escapeHtml(TITLE)}</title>`;
  const desc = `<desc>${escapeHtml(DESC)}</desc>`;
  // Arrow from node 1 to node 2 (public half travels), dashed line from
  // node 3 into the flow it verifies (provenance only). Purely static.
  const links = [
    `<line class="kd-link" x1="230" y1="90" x2="380" y2="90" marker-end="url(#kd-arrow)" />`,
    `<path class="kd-link kd-link-dashed" d="M 305 190 L 305 110" marker-end="url(#kd-arrow)" />`,
  ].join("");
  const markers = [
    `<defs><marker id="kd-arrow" viewBox="0 0 10 10" refX="9" refY="5"`,
    ` markerWidth="7" markerHeight="7" orient="auto-start-reverse">`,
    `<path d="M 0 0 L 10 5 L 0 10 z" class="kd-marker" /></marker></defs>`,
  ].join("");
  const nodes = NODES.map((node) => {
    return [
      `<g class="kd-node">`,
      `<rect x="${String(node.x - 70)}" y="${String(node.y - 28)}" width="140" height="56" rx="8" />`,
      `<text x="${String(node.x)}" y="${String(node.y)}" text-anchor="middle">${escapeHtml(node.label)}</text>`,
      `</g>`,
    ].join("");
  }).join("");
  return [
    `<svg class="key-diagram" xmlns="http://www.w3.org/2000/svg" viewBox="0 0 620 260" role="img" aria-labelledby="key-diagram-title">`,
    title.replace("<title>", `<title id="key-diagram-title">`),
    desc,
    markers,
    links,
    nodes,
    `</svg>`,
  ].join("");
}
