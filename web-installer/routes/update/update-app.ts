/**
 * /install/update browser bootstrap. Renders the update inner chrome and
 * wires data-* actions. Key generation is not offered (D-003).
 *
 * The alpha-posture approval (F-WEBINSTALL-POSTURE-APPROVAL-FLOW) is held here
 * as the value the user TYPED; whether it counts is decided by
 * `evaluatePosture`, never by this file. Nothing is persisted — no storage, no
 * cookie, no URL (D-006/D-007).
 */
import { onPageHide, zeroise } from "../../lib/keys/zeroise.js";
import { initialInstallState, reduce } from "../../lib/install-state/machine.js";
import { deviceFromSearch } from "../../lib/ui/offered-devices.js";
import type { PostureApproval } from "../../lib/ui/posture-approval.js";
import { renderUpdateInner, type UpdatePageModel } from "./update-route.js";

function isSimMode(): boolean {
  return new URLSearchParams(window.location.search).get("sim") === "1";
}

const buffers: Uint8Array[] = [];
let state = initialInstallState("update");
/** The posture approval exactly as typed; validity is `evaluatePosture`'s call. */
let postureApproval: PostureApproval | undefined;

function model(): UpdatePageModel {
  return {
    state,
    simMode: isSimMode(),
    targetProduct: deviceFromSearch(window.location.search),
    ...(postureApproval !== undefined ? { postureApproval } : {}),
  };
}

function render(): void {
  const root = document.getElementById("root");
  if (root === null) {
    throw new Error("#root missing");
  }
  root.innerHTML = renderUpdateInner(model());
}

function cleanup(): void {
  for (const buf of buffers) {
    zeroise(buf);
  }
  buffers.length = 0;
}

function boot(): void {
  onPageHide(cleanup);
  const root = document.getElementById("root");
  if (root === null) {
    throw new Error("#root missing");
  }
  root.addEventListener("click", (event) => {
    const target = event.target;
    if (!(target instanceof HTMLElement)) {
      return;
    }
    const action = target.getAttribute("data-action");
    if (action === "back") {
      state = reduce(state, { type: "back" });
      render();
      return;
    }
    if (action === "files-picked") {
      state = reduce(state, { type: "files-picked" });
      render();
      return;
    }
    if (action === "approve-posture") {
      // Record what was typed. An empty or mistyped value is recorded too, so
      // the gate can name the mismatch instead of silently swallowing it; the
      // verdict — not this assignment — decides whether the flow opens.
      const typed =
        root.querySelector<HTMLInputElement>("[data-role='posture-approval']")?.value ?? "";
      postureApproval = {
        typedCodename: typed,
        forProduct: deviceFromSearch(window.location.search),
      };
      render();
    }
  });
  render();
}

boot();
