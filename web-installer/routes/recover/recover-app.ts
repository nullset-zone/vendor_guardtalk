import { renderRecoverPage, wireRecoverPage } from "./recover-route.js";

function boot(): void {
  const root = document.getElementById("root");
  if (root === null) {
    throw new Error("#root missing");
  }
  const simMode = new URLSearchParams(window.location.search).get("sim") === "1";
  root.innerHTML = renderRecoverPage({ simMode });
  wireRecoverPage(root, {
    onAckTyped: () => {},
    onUnlockRequested: () => {},
    onFlashPkmdRequested: () => {},
    onRelockRequested: () => {},
    onSimToggled: () => {},
  });
}

boot();
