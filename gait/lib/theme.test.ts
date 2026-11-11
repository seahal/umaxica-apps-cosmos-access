import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";

import { applyTheme, readThemeCookie, watchThemeCookie } from "@/lib/theme";

beforeEach(() => {
  document.cookie = "ct=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/";
  document.documentElement.className = "";
  delete document.documentElement.dataset["theme"];
  vi.stubGlobal(
    "matchMedia",
    vi.fn(() => ({ matches: false })),
  );
});

afterEach(() => {
  document.cookie = "ct=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/";
  vi.unstubAllGlobals();
});

describe("readThemeCookie", () => {
  test.each([
    ["dr", "dark"],
    ["dark", "dark"],
    ["li", "light"],
    ["light", "light"],
    ["sy", "system"],
    ["system", "system"],
  ])("maps ct=%s to %s", async (cookieValue, expected) => {
    document.cookie = `ct=${cookieValue}; path=/`;

    await expect(readThemeCookie()).resolves.toBe(expected);
  });

  test.each(["", "unknown"])(
    "uses system for an empty or unsupported ct value (%s)",
    async (cookieValue) => {
      document.cookie = `ct=${cookieValue}; path=/`;

      await expect(readThemeCookie()).resolves.toBe("system");
    },
  );

  test("uses system when ct is absent", async () => {
    await expect(readThemeCookie()).resolves.toBe("system");
  });
});

describe("applyTheme", () => {
  test("writes an explicit dark choice to the document", () => {
    applyTheme("dark");

    expect(document.documentElement.dataset["theme"]).toBe("dark");
    expect(document.documentElement.classList.contains("theme-dark")).toBe(true);
    expect(document.documentElement.classList.contains("dark")).toBe(true);
  });

  test("writes an explicit light choice to the document", () => {
    applyTheme("light");

    expect(document.documentElement.dataset["theme"]).toBe("light");
    expect(document.documentElement.classList.contains("theme-light")).toBe(true);
    expect(document.documentElement.classList.contains("dark")).toBe(false);
  });

  test("uses the system setting for the dark class while preserving system as the choice", () => {
    vi.stubGlobal(
      "matchMedia",
      vi.fn(() => ({ matches: true })),
    );
    applyTheme("system");

    expect(document.documentElement.dataset["theme"]).toBe("system");
    expect(document.documentElement.classList.contains("theme-system")).toBe(true);
    expect(document.documentElement.classList.contains("dark")).toBe(true);
  });
});

test("watchThemeCookie reports normalized cookie changes and deletion", async () => {
  const seen: string[] = [];
  const stop = watchThemeCookie((theme) => seen.push(theme));

  await cookieStore.set({ name: "ct", value: "dr" });
  await cookieStore.delete("ct");
  stop();

  expect(seen).toEqual(["dark", "system"]);
});
