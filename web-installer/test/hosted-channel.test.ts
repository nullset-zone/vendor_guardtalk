import assert from "node:assert/strict";
import { test } from "node:test";
import { WizardGateError } from "../wizard/gating.js";
import { hostedChannelBase } from "../wizard/hosted-channel.js";

test("hosted channel URL is per advertised product", () => {
  assert.equal(hostedChannelBase("tokay"), "../channels/tokay/");
  assert.equal(hostedChannelBase("akita"), "../channels/akita/");
  assert.equal(hostedChannelBase("komodo"), "../channels/komodo/");
  assert.equal(hostedChannelBase("rango"), "../channels/rango/");
});

test("hosted channel URL rejects unstamped products", () => {
  assert.throws(() => hostedChannelBase("shiba"), WizardGateError);
  assert.throws(() => hostedChannelBase("caiman"), WizardGateError);
  assert.throws(() => hostedChannelBase("husky"), WizardGateError);
});
