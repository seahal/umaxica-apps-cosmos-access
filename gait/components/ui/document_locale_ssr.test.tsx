// @vitest-environment node

import { useLocale } from "react-aria-components";
import { renderToStaticMarkup } from "react-dom/server";
import { expect, it } from "vitest";

import DocumentLocale from "@/components/ui/DocumentLocale";

function LocaleConsumer() {
  const { locale } = useLocale();
  return <output>{locale}</output>;
}

it("lets React Aria select a locale when rendering without a browser document", () => {
  const markup = renderToStaticMarkup(
    <DocumentLocale>
      <LocaleConsumer />
    </DocumentLocale>,
  );

  expect(markup).toMatch(/<output>[^<]+<\/output>/u);
});
