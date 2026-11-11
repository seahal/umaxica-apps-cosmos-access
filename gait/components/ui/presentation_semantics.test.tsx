import { render, screen } from "@testing-library/react";
import { describe, expect, it } from "vitest";

import Card from "@/components/ui/Card";
import BirthdateFieldset from "@/features/auth/signup/BirthdateFieldset";

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
  it("keeps the birthdate example visible and described without changing the numeric control contract", () => {
    render(
      <>
        <h2 id="birthday">Birthdate</h2>
        <BirthdateFieldset
          format="YYYY-MM-DD"
          separator="-"
          labelledby="birthday"
          parts={[
            {
              part: "year",
              label: "Year",
              placeholder: "1990",
              value: "1991",
              min: 1900,
              max: 2026,
            },
          ]}
        />
      </>,
    );
    const input = screen.getByRole<HTMLInputElement>("spinbutton", { name: "Year" });
    expect(input.type).toBe("number");
    expect(input.name).toBe("birthdate_year");
    expect(input.min).toBe("1900");
    expect(input.max).toBe("2026");
    expect(input.value).toBe("1991");
    expect(input.required).toBe(true);
    expect(input.autocomplete).toBe("bday-year");
    const hint = screen.getByText("1990", { exact: true });
    expect(input.getAttribute("aria-describedby")).toBe(hint.id);
    expect(hint.compareDocumentPosition(input) & Node.DOCUMENT_POSITION_FOLLOWING).toBeTruthy();
  });
});
