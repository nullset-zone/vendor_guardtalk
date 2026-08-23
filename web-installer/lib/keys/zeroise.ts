/**
 * Best-effort key-material hygiene (D-007 §4). WebCrypto handles are GC'd by
 * the platform; raw buffers we own can be actively zeroed. Neither is a
 * guarantee against snapshots — this is defence in depth, labelled as such.
 */

/** Overwrite the buffer with zeros in place. Returns the same buffer. */
export function zeroise(buf: Uint8Array): Uint8Array {
  buf.fill(0);
  return buf;
}

/**
 * Scrub known secret fields of an object (typed arrays and strings replaced
 * with empty values). Best-effort: frozen objects and getters are skipped.
 */
export function scrub<T extends object>(obj: T): T {
  for (const [key, value] of Object.entries(obj)) {
    if (value instanceof Uint8Array) {
      value.fill(0);
      obj[key as keyof T] = new Uint8Array(0) as T[keyof T];
    } else if (typeof value === "string") {
      obj[key as keyof T] = "" as T[keyof T];
    }
  }
  return obj;
}

/**
 * Install a pagehide hook that runs the given cleanup once. Returns an
 * uninstall function. Used to zero transient buffers when the tab is hidden
 * or closed.
 */
export function onPageHide(cleanup: () => void): () => void {
  const handler = (): void => {
    cleanup();
  };
  window.addEventListener("pagehide", handler, { once: true });
  return () => {
    window.removeEventListener("pagehide", handler);
  };
}
