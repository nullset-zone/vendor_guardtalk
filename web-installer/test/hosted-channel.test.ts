import assert from "node:assert/strict";
import { test } from "node:test";
import { WizardGateError } from "../wizard/gating.js";
import { hostedChannelBase } from "../wizard/hosted-channel.js";

test("hosted channel URL is per advertised product", () => {
  assert.equal(hostedChannelBase("tokay"), "../channels/tokay/");
  assert.equal(hostedChannelBase("akita"), "../channels/akita/");
});

test("hosted channel URL rejects rango and shiba", () => {
  assert.throws(() => hostedChannelBase("rango"), WizardGateError);
  assert.throws(() => hostedChannelBase("shiba"), WizardGateError);
});
