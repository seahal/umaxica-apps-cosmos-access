import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import Card from "@/components/ui/Card";

describe("presentation semantics", () => {
  it("keeps an untitled panel a plain group rather than an unnamed section", () => {
    const { container } = render(
      <Card>
        <p>Account details</p>
      </Card>,
    );
    expect(container.firstElementChild?.tagName).toBe("DIV");
  });
  it("names a subject card with its visible heading", () => {
    render(
      <Card heading="Account details">
        <p>Details</p>
      </Card>,
    );
    const region = screen.getByRole("region", { name: "Account details" });
    expect(region.querySelector("h2")?.textContent).toBe("Account details");
  });
});
