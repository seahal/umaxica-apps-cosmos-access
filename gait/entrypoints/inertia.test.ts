import { createInertiaApp } from "@inertiajs/react";
import { afterEach, beforeEach, describe, expect, test, vi } from "vitest";

import {
  bootSurfaceInertiaApp,
  reportInertiaBootFailure,
  surfaceInertiaDefaults,
  surfacePageResolver,
} from "@/inertia/surface";

vi.mock("@inertiajs/react", () => ({
  createInertiaApp: vi.fn(() => Promise.resolve("booted")),
}));

const layout = () => null;

describe("surface page resolver", () => {
  test("resolves a page from its Auth surface glob and attaches the layout", () => {
    const resolve = surfacePageResolver(
      { "../../pages/auth/app/sign_ins/new.tsx": { default: () => null } },
      "auth/app",
      layout,
    );

    expect(resolve("auth/app/sign_ins/new").default.layout).toEqual([layout]);
  });

  test("rejects another surface's page", () => {
    const resolve = surfacePageResolver(
      { "../../pages/auth/app/sign_ins/new.tsx": { default: () => null } },
      "auth/app",
      layout,
    );

    expect(() => resolve("visa/app/oidc/logouts/show")).toThrow(
      /does not belong to the "auth\/app" surface/u,
    );
  });

  test("rejects an unqualified page name", () => {
    const resolve = surfacePageResolver({}, "visa/org", layout);

    expect(() => resolve("oidc/logouts/show")).toThrow(
      /does not belong to the "visa\/org" surface/u,
    );
  });

  test("rejects a globbed module without a default page export", () => {
    expect(() =>
      surfacePageResolver(
        { "../../pages/visa/org/oidc/logouts/show.tsx": { named: true } },
        "visa/org",
        layout,
      ),
    ).toThrow(/has no default export/u);
  });

  test("fails when the server renders a page missing from the surface glob", () => {
    const resolve = surfacePageResolver({}, "visa/app", layout);

    expect(() => resolve("visa/app/oidc/logouts/show")).toThrow(
      /has no component in src\/pages\/visa\/app/u,
    );
  });
});

test("Inertia visits use bracket array syntax so Rack parses array parameters", () => {
  expect(surfaceInertiaDefaults.visitOptions()).toEqual({ queryStringArrayFormat: "brackets" });
});

describe("reportInertiaBootFailure", () => {
  afterEach(() => {
    document.body.innerHTML = "";
  });

  test("rethrows the original error when the Inertia root element is present", () => {
    document.body.innerHTML = '<div id="app"></div>';
    const error = new Error("boot failed");

    expect(() => reportInertiaBootFailure(error)).toThrow(error);
  });
});

describe("bootSurfaceInertiaApp", () => {
  beforeEach(() => {
    document.cookie = "ct=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/";
    document.documentElement.className = "";
    delete document.documentElement.dataset["theme"];
    document.body.innerHTML = '<div id="app"></div>';
    vi.clearAllMocks();
  });

  afterEach(() => {
    document.cookie = "ct=; expires=Thu, 01 Jan 1970 00:00:00 GMT; path=/";
    document.body.innerHTML = "";
  });

  test("applies the Auth theme cookie on boot and when it changes", async () => {
    document.cookie = "ct=dr; path=/";

    await bootSurfaceInertiaApp({}, "auth/app");
    await vi.waitFor(() => expect(document.documentElement.dataset["theme"]).toBe("dark"));

    await cookieStore.set({ name: "ct", value: "li" });
    await vi.waitFor(() => expect(document.documentElement.dataset["theme"]).toBe("light"));
    expect(createInertiaApp).toHaveBeenCalledTimes(1);
  });
});
