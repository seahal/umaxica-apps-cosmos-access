import { execFileSync } from "node:child_process";

import { AxeBuilder } from "@axe-core/playwright";
import { expect, test } from "playwright/test";

// Cookies stay in memory; retained traces could expose credentials.
test.use({ trace: "off" });

type Fixture = { cookie: string; access: string; sessionId: number };
let fixture: Fixture = { cookie: "", access: "", sessionId: 0 };

test.beforeAll(() => {
  const payload: unknown = JSON.parse(
    execFileSync(
      "bin/rails",
      [
        "runner",
        "-e",
        "test",
        `abort 'test required' unless Rails.env.test?
client = Client.create!(status_id: ClientStatus::ACTIVE, birthdate: '2000-01-01')
token = ClientToken.create!(user: client, root_login_established_at: Time.current, established_authentication_method: 'passkey')
access = AuthenticationToken.encode(client, host: 'auth.app.localhost', session_public_id: token.public_id, resource_type: 'client', jwt_issuer_id: 'surface:AUTH_APP')
STDOUT.write({cookie: AuthenticationBase::ACCESS_COOKIE_KEY, access: access, session_id: token.id}.to_json)`,
      ],
      { encoding: "utf8" },
    ),
  );

  if (typeof payload !== "object" || payload === null) {
    throw new Error("The Auth session fixture is missing.");
  }

  const cookie: unknown = Reflect.get(payload, "cookie");
  const access: unknown = Reflect.get(payload, "access");
  const sessionId: unknown = Reflect.get(payload, "session_id");
  if (
    typeof cookie !== "string" ||
    typeof access !== "string" ||
    typeof sessionId !== "number" ||
    !Number.isSafeInteger(sessionId) ||
    sessionId <= 0
  ) {
    throw new Error("The Auth session fixture has an invalid shape.");
  }

  fixture = { cookie, access, sessionId };
});

test.afterAll(() => {
  if (fixture.sessionId > 0) {
    execFileSync(
      "bin/rails",
      ["runner", "-e", "test", `ClientToken.find(${fixture.sessionId}).revoke!`],
      { stdio: "pipe" },
    );
  }
});

const journeys = [
  { path: "/settings/passkeys", heading: "Passkeys" },
  { path: "/settings/totps", heading: "Totps" },
];

const presentations = [
  ...[320, 768, 1024, 1440].map((width) => ({
    width,
    language: "en",
    theme: "light",
    code: "li",
    os: "light" as const,
  })),
  { width: 320, language: "ja", theme: "dark", code: "dr", os: "light" as const },
  { width: 320, language: "en", theme: "system", code: "sy", os: "dark" as const },
  { width: 1440, language: "ja", theme: "system", code: "sy", os: "light" as const },
];

for (const journey of journeys) {
  for (const presentation of presentations) {
    const { width, language, theme, code, os } = presentation;
    test(`Auth app${journey.path} has readable presentation at ${width}px in ${language}/${theme}/OS-${os}`, async ({
      browser,
    }) => {
      const context = await browser.newContext({
        viewport: { width, height: 900 },
        colorScheme: os,
        reducedMotion: "reduce",
      });
      try {
        await context.addCookies([
          {
            name: fixture.cookie,
            value: fixture.access,
            url: "http://auth.app.localhost:3188",
            httpOnly: true,
          },
          { name: "ct", value: code, url: "http://auth.app.localhost:3188" },
        ]);
        const page = await context.newPage();
        await page.route("**/*", (route) => {
          // oxlint-disable-next-line vitest/no-conditional-in-test
          return new URL(route.request().url()).hostname === "auth.app.localhost"
            ? route.continue()
            : route.abort();
        });
        const response = await page.goto(
          `http://auth.app.localhost:3188${journey.path}?ri=jp&lx=${language}`,
        );
        expect(response?.status()).toBe(200);
        const title = page.getByRole("main").getByRole("heading", { level: 1 });
        await expect(title).toBeVisible();
        await expect(title).toHaveText(journey.heading);
        await expect(page.locator("html")).toHaveAttribute("data-theme", theme);
        expect(await page.evaluate(() => document.documentElement.scrollWidth)).toBeLessThanOrEqual(
          width,
        );
        await page.keyboard.press("Tab");
        await expect(page.locator(".ui-skip-link")).toBeFocused();
        await page.keyboard.press("Enter");
        await expect(page.getByRole("main")).toBeFocused();
        const audit = await new AxeBuilder({ page })
          .withTags(["wcag2a", "wcag2aa", "wcag21aa", "wcag22aa"])
          .analyze();
        expect(audit.violations).toEqual([]);
        await page.screenshot({
          path: `/tmp/umaxica-ui-normalization-continuation/auth.app.localhost-${journey.path.replaceAll("/", "-")}-${width}-${language}-${theme}-OS-${os}.png`,
          fullPage: true,
        });
      } finally {
        await context.close();
      }
    });
  }
}
