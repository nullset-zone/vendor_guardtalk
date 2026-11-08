/**
 * Production-release honesty (F-EXCISE-RELEASE-HONESTY).
 * Reads src/types.ts. No live USB flash. No production-release claim.
 */
import assert from "node:assert/strict";
import { readFileSync } from "node:fs";
import { join } from "node:path";
import { fileURLToPath } from "node:url";
import { test } from "node:test";

const ROOT = fileURLToPath(new URL("..", import.meta.url));

test("LIVE_FLASH_CLAIMED and PRODUCTION_RELEASE_CLAIMED stay false", () => {
  const types = readFileSync(join(ROOT, "src/types.ts"), "utf8");
  assert.match(types, /export const LIVE_FLASH_CLAIMED = false;/);
  assert.match(types, /export const PRODUCTION_RELEASE_CLAIMED = false;/);
  assert.doesNotMatch(types, /LIVE_FLASH_CLAIMED = true/);
  assert.doesNotMatch(types, /PRODUCTION_RELEASE_CLAIMED = true/);
});
