// The invisible Turnstile token the fetch-driven passkey ceremonies solve before they call the
// server. The server verifies the token, so the client never decides whether the challenge passed.
//
// `src/features/turnstile/TurnstileWidget.tsx` covers the two widget shapes that sit next to a
// form; this covers the third shape, the one that solves a token on demand inside a JSON ceremony.
import { waitForTurnstileApi, type TurnstileOptions } from "@/lib/turnstile";

type InvisibleTurnstileOptions = TurnstileOptions & { size: "invisible" };

export async function solveInvisibleTurnstile(
  siteKey: string,
  errorMessage: string,
  host: HTMLElement | null,
): Promise<string> {
  if (!siteKey) {
    throw new Error(errorMessage);
  }

  const turnstile = await waitForTurnstileApi(errorMessage);

  return new Promise<string>((resolve, reject) => {
    const container = document.createElement("div");
    // `hidden` rather than an inline style: it is the platform attribute for "not rendered and

    // not announced", and it keeps the widget host out of the accessibility tree too.

    container.hidden = true;
    (host ?? document.body).append(container);

    const options: InvisibleTurnstileOptions = {
      sitekey: siteKey,
      size: "invisible",
      callback: (token: string) => resolve(token),
      "error-callback": () => {
        reject(new Error(errorMessage));
        return true;
      },
      "expired-callback": () => reject(new Error(errorMessage)),
      "timeout-callback": () => reject(new Error(errorMessage)),
      "unsupported-callback": () => reject(new Error(errorMessage)),
    };

    try {
      turnstile.render(container, options);
    } catch (error) {
      // The caller is given the visitor-facing message; the underlying failure is only useful
      // here.
      // oxlint-disable-next-line no-console
      console.error("Turnstile token request failed:", error);
      reject(new Error(errorMessage));
    }
  });
}
