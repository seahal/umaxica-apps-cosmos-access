// Read the server-owned theme projection through the Cookie Store API. The browser code never
// writes it; the verified preference state remains on the server.

/** The document's cookie store. It is available only in secure contexts, including localhost. */
function cookieJar(): CookieStore {
  const available = typeof window !== "undefined" && typeof window.cookieStore !== "undefined";

  if (!available) {
    throw new Error(
      "window.cookieStore is unavailable: the Cookie Store API needs a secure context " +
        "(HTTPS, or localhost in development) and a supported browser.",
    );
  }

  return window.cookieStore;
}

/** What a cookie's stored value means to the application. */
function cookieValue(cookie: CookieListItem | null | undefined): string | null {
  return cookie?.value ? decodeURIComponent(cookie.value) : null;
}

/** The value of a cookie by name, or null when the document does not carry it. */
export async function readCookie(name: string): Promise<string | null> {
  return cookieValue(await cookieJar().get(name));
}

/**
 * Calls back with a cookie's new value whenever it changes, and with null when it is deleted.
 * Returns an unsubscribe function.
 */
export function watchCookie(name: string, listener: (value: string | null) => void): () => void {
  const store = cookieJar();
  const onChange = (event: CookieChangeEvent) => {
    const changed = event.changed.find((cookie) => cookie.name === name);

    if (changed) {
      listener(cookieValue(changed));
      return;
    }

    if (event.deleted.some((cookie) => cookie.name === name)) {
      listener(null);
    }
  };

  store.addEventListener("change", onChange);
  return () => store.removeEventListener("change", onChange);
}
