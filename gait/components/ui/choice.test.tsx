import { render, screen } from "@testing-library/react";
import userEvent from "@testing-library/user-event";
import { describe, expect, it, vi } from "vitest";

const { default: Checkbox } = await import("@/components/ui/Checkbox");

describe("Checkbox", () => {
  it("is a real checkbox named by its content", () => {
    render(<Checkbox>Functional cookies</Checkbox>);

    expect(screen.getByRole("checkbox", { name: "Functional cookies" })).toBeTruthy();
  });

  it("toggles with the Space key", async () => {
    const user = userEvent.setup();
    const changed = vi.fn();
    render(<Checkbox onChange={changed}>Functional cookies</Checkbox>);

    await user.tab();
    await user.keyboard(" ");

    expect(changed).toHaveBeenLastCalledWith(true);
  });

  it("toggles on a pointer press", async () => {
    const user = userEvent.setup();
    const changed = vi.fn();
    render(<Checkbox onChange={changed}>Functional cookies</Checkbox>);

    await user.click(screen.getByRole("checkbox", { name: "Functional cookies" }));

    expect(changed).toHaveBeenLastCalledWith(true);
  });

  it("reports a checked default", () => {
    render(<Checkbox defaultSelected>Functional cookies</Checkbox>);

    expect(
      screen.getByRole<HTMLInputElement>("checkbox", { name: "Functional cookies" }).checked,
    ).toBe(true);
  });

  it("cannot be toggled while disabled", async () => {
    const user = userEvent.setup();
    const changed = vi.fn();
    render(
      <Checkbox
        isDisabled
        onChange={changed}
      >
        Functional cookies
      </Checkbox>,
    );

    await user.click(screen.getByRole("checkbox", { name: "Functional cookies" }));

    expect(changed).not.toHaveBeenCalled();
  });

  it("reports the indeterminate state rather than guessing a value", () => {
    render(<Checkbox isIndeterminate>Functional cookies</Checkbox>);

    // A native checkbox carries this as a DOM property, which is what the accessibility tree reads;
    // there is no `aria-checked` attribute on a real `<input type="checkbox">`.
    const input = screen.getByRole<HTMLInputElement>("checkbox", { name: "Functional cookies" });
    expect(input.indeterminate).toBe(true);
  });
});
