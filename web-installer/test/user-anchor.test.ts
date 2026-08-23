import assert from "node:assert/strict";
import { test } from "node:test";
import { proveVbmetaUserSigned } from "../lib/verify/user-anchor.js";
import { signedAnchor } from "./fixtures/signed-anchor.js";

test("proveVbmetaUserSigned accepts the enrolled pkmd and refuses a dummy blob", async () => {
  const anchor = await signedAnchor();
  const ok = await proveVbmetaUserSigned(anchor.vbmeta, anchor.pkmd);
  assert.deepEqual(ok, { ok: true });

  const wrongKey = await proveVbmetaUserSigned(anchor.vbmeta, new Uint8Array(anchor.pkmd.length));
  assert.equal(wrongKey.ok, false);

  const garbage = await proveVbmetaUserSigned(new Uint8Array(64), anchor.pkmd);
  assert.equal(garbage.ok, false);
  assert.ok(garbage.reason && garbage.reason.length > 0);
});
