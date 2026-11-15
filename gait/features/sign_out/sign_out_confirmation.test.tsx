import { renderToStaticMarkup } from "react-dom/server";
import { expect, it } from "vitest";

import SignOutConfirmation from "@/features/sign_out/SignOutConfirmation";

const common = {
  title: "Sign out",
  active: false,
  description: "End this session.",
  form: null,
};

it("rejects a sign-out page that supplies both return destinations", () => {
  const props = {
    ...common,
    back_link: { label: "Back", href: "/back" },
    home_link: { label: "Home", href: "/" },
  };

  expect(() =>
    renderToStaticMarkup(
      // @ts-expect-error Rails can supply malformed serialized props; the page must still fail closed.
      <SignOutConfirmation {...props} />,
    ),
  ).toThrow("A sign-out page must provide one return link");
});

it("rejects a sign-out page without a return destination", () => {
  const props = common;

  expect(() =>
    renderToStaticMarkup(
      // @ts-expect-error Rails can supply malformed serialized props; the page must still fail closed.
      <SignOutConfirmation {...props} />,
    ),
  ).toThrow("A sign-out return link is required");
});
