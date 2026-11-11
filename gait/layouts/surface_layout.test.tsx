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
  banner: null,
  restricted_mode: null,
  copyright: "(c) Umaxica",
};

const page: { props: { chrome: SurfaceChrome; clear_history?: boolean } } = {
  props: { chrome: minimalChrome },
};

beforeEach(() => {
  vi.mocked(router.clearHistory).mockClear();
  document.documentElement.lang = "en";
  document.head.insertAdjacentHTML(
    "beforeend",
    '<meta name="ui-information" content="Information">',
  );
});

afterEach(() => {
  page.props.chrome = minimalChrome;
  delete page.props.clear_history;
  document.querySelectorAll('meta[name="ui-information"]').forEach((meta) => meta.remove());
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

  test("renders the family label only when present", () => {
    page.props.chrome = { ...minimalChrome, family_label: "Auth" };

    render(
      <SurfaceLayout>
        <p>page body</p>
      </SurfaceLayout>,
    );

    expect(document.body.textContent).toContain("Auth");
  });

  test("renders a banner with a title", () => {
    page.props.chrome = {
      ...minimalChrome,
      banner: { title: "Maintenance", body: "A maintenance window is planned." },
    };

    render(
      <SurfaceLayout>
        <p>page body</p>
      </SurfaceLayout>,
    );

    const banner = screen.getByRole("region", { name: "Maintenance" });
    expect(within(banner).getByRole("heading", { name: "Maintenance" })).toBeTruthy();
    expect(within(banner).getByText("A maintenance window is planned.")).toBeTruthy();
  });

  test("uses the information landmark name when the banner has no title", () => {
    page.props.chrome = {
      ...minimalChrome,
      banner: { title: null, body: "Information body" },
    };

    render(
      <SurfaceLayout>
        <p>page body</p>
      </SurfaceLayout>,
    );

    const banner = screen.getByRole("region", { name: "Information" });
    expect(within(banner).getByText("Information body")).toBeTruthy();
    expect(within(banner).queryByRole("heading")).toBeNull();
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
