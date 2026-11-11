// Keep Auth and Visa documents in step with the server-owned theme cookie.

import { readCookie, watchCookie } from "@/lib/cookies";

type Theme = "dark" | "light" | "system";

const THEME_BY_CODE: Record<string, Theme> = {
  dr: "dark",
  dark: "dark",
  li: "light",
  light: "light",
  sy: "system",
  system: "system",
};

function themeFromCode(value: string | null | undefined): Theme {
  if (value === undefined || value === null || value.length === 0) {
    return "system";
  }
  return THEME_BY_CODE[value.toLowerCase()] ?? "system";
}

/** The stored theme in the current surface's display cookie. */
export async function readThemeCookie(): Promise<Theme> {
  return themeFromCode(await readCookie("ct"));
}

/** Calls back when the server changes the document's theme projection. */
export function watchThemeCookie(listener: (theme: Theme) => void): () => void {
  return watchCookie("ct", (value) => listener(themeFromCode(value)));
}

export function applyTheme(theme: Theme): void {
  const html = document.documentElement;
  const applied =
    theme === "system"
      ? window.matchMedia("(prefers-color-scheme: dark)").matches
        ? "dark"
        : "light"
      : theme;

  html.dataset["theme"] = theme;
  html.classList.remove("theme-dark", "theme-light", "theme-system");
  html.classList.add(`theme-${theme}`);
  html.classList.toggle("dark", applied === "dark");
}
