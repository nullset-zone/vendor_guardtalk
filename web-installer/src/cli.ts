#!/usr/bin/env node
/**
 * Host harness: load a channel directory and print the flash plan.
 * Does not open WebUSB or claim a live flash.
 */
import { loadChannelFromDir } from "./channel-fs.js";
import { FLASH_ORDER, LIVE_FLASH_CLAIMED } from "./types.js";
import { buildFlashPlan, flashPhaseSequence } from "./plan.js";

async function main(): Promise<void> {
  const dir = readArg("--channel");
  if (dir === undefined) {
    console.error("usage: tsx src/cli.ts --channel DIR");
    process.exit(2);
  }
  const channel = await loadChannelFromDir(dir);
  const plan = buildFlashPlan(channel);
  const payload = {
    liveFlashClaimed: LIVE_FLASH_CLAIMED,
    product: plan.product,
    flashOrder: FLASH_ORDER,
    flashPhaseSequence: flashPhaseSequence(plan),
    steps: plan.steps,
  };
  process.stdout.write(`${JSON.stringify(payload, null, 2)}\n`);
}

function readArg(flag: string): string | undefined {
  const idx = process.argv.indexOf(flag);
  if (idx < 0) {
    return undefined;
  }
  return process.argv[idx + 1];
}

main().catch((err: unknown) => {
  const message = err instanceof Error ? err.message : String(err);
  console.error(message);
  process.exit(1);
});
