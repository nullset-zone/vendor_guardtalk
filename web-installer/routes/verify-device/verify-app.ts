import { renderVerifyDevicePage, wireVerifyPage } from "./verify-route.js";

function boot(): void {
  const root = document.getElementById("root");
  if (root === null) {
    throw new Error("#root missing");
  }
  const simMode = new URLSearchParams(window.location.search).get("sim") === "1";
  root.innerHTML = renderVerifyDevicePage({ simMode });
  wireVerifyPage(root, {
    onReadRequested: () => {},
    onCompareRequested: () => {},
    onSimToggled: () => {},
  });
}

boot();
