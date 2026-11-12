import { render, screen } from "@testing-library/react";
import type { ReactNode } from "react";
import { afterEach, describe, expect, it, vi } from "vitest";

import AppLogoutPage from "@/pages/visa/app/oidc/logouts/show";
import OrgLogoutPage from "@/pages/visa/org/oidc/logouts/show";

// The Inertia adapter is outside this native form contract; retain its destination markup.
vi.mock("@inertiajs/react", () => ({
  Link: ({ href, children }: { href: string; children: ReactNode }) => (
    <a href={href}>{children}</a>
  ),
}));

afterEach(() => document.head.querySelector('meta[name="csrf-token"]')?.remove());

describe.each([
  ["APP", AppLogoutPage],
  ["ORG", OrgLogoutPage],
] as const)("retained Visa %s logout page", (_realm, LogoutPage) => {
  it("keeps confirmation as an explicit native CSRF protected POST", () => {
    const meta = document.createElement("meta");
    meta.name = "csrf-token";
    meta.content = "synthetic-session-csrf";
    document.head.append(meta);
    const { container } = render(
      <LogoutPage
        title="Sign out"
        description="End this session."
        active
        form={{
          action: "/oidc/logout/confirmation",
          submit: "Confirm sign out",
          confirm_description: "Confirm the request.",
        }}
        back_link={{ href: "/", label: "Back" }}
      />,
    );

    const form = container.querySelector("form");
    expect(form?.getAttribute("action")).toBe("/oidc/logout/confirmation");
    expect(form?.getAttribute("method")).toBe("post");
    expect(form?.dataset["turbo"]).toBe("false");
    expect(form?.querySelector<HTMLInputElement>('input[name="authenticity_token"]')?.value).toBe(
      "synthetic-session-csrf",
    );
    expect(screen.getByRole("button", { name: "Confirm sign out" }).getAttribute("type")).toBe(
      "submit",
    );
    expect(screen.getByRole("link", { name: "Back" }).getAttribute("href")).toBe("/");
  });

  it("offers only the supplied return destination when there is no session to end", () => {
    const { container } = render(
      <LogoutPage
        title="Signed out"
        description="The session has ended."
        active={false}
        form={null}
        home_link={{ href: "/", label: "Home" }}
      />,
    );

    expect(screen.getByRole("heading", { name: "Signed out", level: 1 })).toBeTruthy();
    expect(container.querySelector("form")).toBeNull();
    expect(screen.queryByRole("button")).toBeNull();
    expect(screen.getByRole("link", { name: "Home" }).getAttribute("href")).toBe("/");
  });
});
