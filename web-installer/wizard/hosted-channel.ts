import { isAllowedProduct } from "../src/allowlist.js";
import { WizardGateError } from "./gating.js";
import type { ChannelTexts } from "./session.js";
import type { AllowedProduct } from "../src/types.js";

/** Server-hosted packed channels (packed next to this wizard). */
export function hostedChannelBase(product: string): string {
  if (!isAllowedProduct(product)) {
    throw new WizardGateError(`no hosted channel for '${product}'`);
  }
  return `../channels/${product}/`;
}

export async function fetchHostedChannel(product: string): Promise<{
  product: AllowedProduct;
  baseUrl: string;
  texts: ChannelTexts;
}> {
  if (!isAllowedProduct(product)) {
    throw new WizardGateError(`no hosted channel for '${product}'`);
  }
  const baseUrl = hostedChannelBase(product);
  const [manifestJson, sha256sums, filesTxt] = await Promise.all([
    fetchHostedText(`${baseUrl}manifest.json`),
    fetchHostedText(`${baseUrl}SHA256SUMS`),
    fetchHostedText(`${baseUrl}files.txt`),
  ]);
  return {
    product,
    baseUrl,
    texts: { manifestJson, sha256sums, filesTxt },
  };
}

async function fetchHostedText(url: string): Promise<string> {
  const response = await fetch(url);
  if (!response.ok) {
    throw new Error(`could not fetch ${url} (${String(response.status)})`);
  }
  return response.text();
}
