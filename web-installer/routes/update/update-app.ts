/**
 * /install/update browser bootstrap. Renders the update inner chrome and
 * wires data-* actions. Key generation is not offered (D-003).
 */
import { onPageHide, zeroise } from "../../lib/keys/zeroise.js";
import { initialInstallState, reduce } from "../../lib/install-state/machine.js";
import { renderUpdateInner, type UpdatePageModel } from "./update-route.js";

function isSimMode(): boolean {
  return new URLSearchParams(window.location.search).get("sim") === "1";
}

const buffers: Uint8Array[] = [];
let state = initialInstallState("update");

function model(): UpdatePageModel {
  return {
    state,
    simMode: isSimMode(),
    targetProduct: "tokay",
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
    if (target.getAttribute("data-action") === "files-picked") {
      state = reduce(state, { type: "files-picked" });
      render();
    }
  });
  render();
}

boot();
