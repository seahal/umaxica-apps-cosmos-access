import { beforeEach, describe, expect, test, vi } from "vitest";

vi.mock("@/inertia/surface", () => ({ bootSurfaceInertiaApp: vi.fn() }));

const { bootSurfaceInertiaApp } = await import("@/inertia/surface");

beforeEach(() => vi.clearAllMocks());

describe("Visa Inertia entrypoints", () => {
  test("boots APP with only the APP page glob", async () => {
    await import("@/entrypoints/inertia/visa_app");

    const {
      mock: { calls },
    } = vi.mocked(bootSurfaceInertiaApp);
    expect(calls.map(([, surface]) => surface)).toEqual(["visa/app"]);
    expect(calls.map(([modules]) => Object.keys(modules))).toEqual([
      ["../../pages/visa/app/oidc/logouts/show.tsx"],
    ]);
  });

  test("boots ORG with only the ORG page glob", async () => {
    await import("@/entrypoints/inertia/visa_org");

    const {
      mock: { calls },
    } = vi.mocked(bootSurfaceInertiaApp);
    expect(calls.map(([, surface]) => surface)).toEqual(["visa/org"]);
    expect(calls.map(([modules]) => Object.keys(modules))).toEqual([
      ["../../pages/visa/org/oidc/logouts/show.tsx"],
    ]);
  });
});
