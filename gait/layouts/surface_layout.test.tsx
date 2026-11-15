import { router } from "@inertiajs/react";
import { render, screen, within } from "@testing-library/react";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";

import type { SurfaceChrome } from "@/types/inertia";

vi.mock("@inertiajs/react", () => ({
  usePage: () => page,
  router: { clearHistory: vi.fn() },
}));

const { default: SurfaceLayout } = await import("@/layouts/SurfaceLayout");

const minimalChrome: SurfaceChrome = {
  family_label: null,
  surface: "app",
  brand: { name: "Umaxica", href: "https://umaxica.app/" },
  restricted_mode: null,
  copyright: "(c) Umaxica",
};

const page: { props: { chrome: SurfaceChrome; clear_history?: boolean } } = {
  props: { chrome: minimalChrome },
};

beforeEach(() => {
  vi.mocked(router.clearHistory).mockClear();
  document.documentElement.lang = "en";
});

afterEach(() => {
  page.props.chrome = minimalChrome;
  delete page.props.clear_history;
});

describe("SurfaceLayout", () => {
  test("renders the page inside the main landmark and shows server-resolved chrome", () => {
    render(
      <SurfaceLayout>
        <p>page body</p>
      </SurfaceLayout>,
    );

    const main = screen.getByRole("main");
    expect(main.id).toBe("main");
    expect(within(main).getByText("page body")).toBeTruthy();
    expect(screen.getByRole("link", { name: "Umaxica" }).getAttribute("href")).toBe(
      "https://umaxica.app/",
    );
    expect(document.body.textContent).toContain("(app)");
    expect(document.body.textContent).toContain("(c) Umaxica");
  });

  test("renders a brand without a destination as text rather than inventing a link", () => {
    page.props.chrome = { ...minimalChrome, brand: { name: "Umaxica", href: null } };

    render(
      <SurfaceLayout>
        <p>page body</p>
      </SurfaceLayout>,
    );

    expect(screen.getByText("Umaxica").tagName).toBe("SPAN");
    expect(screen.queryByRole("link", { name: "Umaxica" })).toBeNull();
  });

  test("renders the family label only when present", () => {
    page.props.chrome = { ...minimalChrome, family_label: "Auth" };

    render(
      <SurfaceLayout>
        <p>page body</p>
      </SurfaceLayout>,
    );

    expect(document.body.textContent).toContain("Auth");
  });

  test("renders Restricted Mode above the ordinary surface chrome", () => {
    page.props.chrome = {
      ...minimalChrome,
      restricted_mode: {
        label: "Emergency Access",
        description: "Some authentication methods are unavailable.",
        sign_out: { label: "Sign out and sign in normally", href: "/sign/out" },
      },
    };

    render(
      <SurfaceLayout>
        <p>page body</p>
      </SurfaceLayout>,
    );

    const indicator = screen.getByRole("region", { name: "Emergency Access" });
    expect(
      within(indicator).getByText("Some authentication methods are unavailable."),
    ).toBeTruthy();
    expect(
      within(indicator)
        .getByRole("link", { name: "Sign out and sign in normally" })
        .getAttribute("href"),
    ).toBe("/sign/out");
  });

  test("clears encrypted history when the server marks a terminal ceremony page", () => {
    page.props.clear_history = true;

    render(
      <SurfaceLayout>
        <p>page body</p>
      </SurfaceLayout>,
    );

    expect(router.clearHistory).toHaveBeenCalledTimes(1);
  });
});
