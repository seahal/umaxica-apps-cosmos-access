# Access: Remove Inertia, Render Ceremonies on the Server (plan, 2026-11-12)

Implements `adr/cosmos-identity-without-inertia.md` (accepted 2026-11-08; conversion order was left
open). The owner asked on 2026-11-12 for a way to finish the JavaScript-dependent screens because
the work spans many sessions. This plan splits it into batches; each batch is one Codex session with
its own evidence record. No commit unless the owner asks.

## Target (from the ADR)

- Server-rendered ERB views, forms submitted as normal requests (POST, then redirect).
- Stimulus (or a small module) only where it is needed: WebAuthn for passkeys (required; owner
  confirmed 2026-11-12) and the one-time-code resend control (UI/UX enhancement; owner, 2026-11-12).
  No `inertia_rails`, no `@inertiajs/*`, no `src/pages/**` for Access, no `inertia_clear_history`.
- **JavaScript allow-list (owner, 2026-11-12).** Access's own JavaScript is limited to exactly these
  two modules; every other screen and control works with HTML forms and server responses only.
  Reason: browser JavaScript APIs and behavior change over time, and the owner does not want sign-in
  to depend on them beyond what WebAuthn forces. Enforce it with a static guard test that lists the
  allowed modules and fails on any other Access JavaScript entry point. Allowed third-party script
  (owner, 2026-11-12): **Cloudflare Turnstile**, loaded only where a Turnstile placement exists
  today (`adr/turnstile-visible-placement-policy.md`,
  `adr/sign-up-checkpoint-turnstile-boundary.md`). Its token is still verified on the server; a
  missing or invalid token is refused as today. The guard test lists Turnstile's script origin as
  the only allowed third-party script; any other third-party script fails the test.
- Every ceremony response sends `Cache-Control: no-store`; nothing sensitive in URLs; back, forward
  and reload are verified per ceremony (ADR amendment of 2026-11-10).
- Screens use the centered ceremony layout
  (`docs/backlog/2026-11-10-access-centered-ceremony-layout.md`): build it once in batch 0 and use
  it for every converted screen.
- Deletion, not a compatibility layer: when a screen is converted, its Inertia page, props and tests
  are removed in the same batch.

## Inventory (2026-11-12): 37 controllers render Inertia

Concerns: `app_sign_up_checkpoint_page`, `visa_app_oidc_logout_endpoint`,
`visa_org_oidc_logout_endpoint`, `auth_passkey_registration_ceremony`, `surface_inertia_page`,
`visa_sign_in_limitations`. Controllers under `auth/app/sign/{ins,ups}`, `auth/app/sign/in/**`,
`auth/app/sign/up/**`, `auth/app/verification/**`, `auth/app/verifications`,
`auth/app/settings/{totps,apples,googles}`, `auth/org/sign/**`, `auth/org/verification/**`,
`auth/org/verifications`, `visa/app/sign/in/limitations`. Regenerate the list at the start of each
batch with `grep -rl "render inertia" app/controllers`.

## Batches (one session each; order chosen so each batch is small and testable)

0. **Foundation.** Centered ERB layout for Auth and Visa (app and org), shared form, error and
   notice partials (no flash; `generic/no-flash-messages.mdc`), `no-store` headers, and a
   request-test helper that checks back/forward/reload safety. No screen converted yet.
1. **Simple confirmation screens.** OIDC logout confirmation and completion (app, org), session
   limit screen (`visa/app/sign/in/limitations`, "too many sessions, choose which to end"), sign-in
   and sign-up result pages. Plain forms only.
2. **One-time-code screens.** Email and telephone code entry and redelivery for sign-in, sign-up and
   verification (app, org). The redelivery (resend) control keeps a small JavaScript enhancement for
   UI/UX (owner, 2026-11-12), for example a countdown until resend is allowed. The server still
   enforces the cooldown and limits, and the resend button remains a normal POST form that works
   without JavaScript.
3. **Passkey screens.** Sign-in, step-up, emergency (org) and registration ceremonies: server page +
   one small WebAuthn module (Stimulus). JavaScript is required here and is not optional: the
   WebAuthn API (`navigator.credentials.create` and `get`) exists only in JavaScript, so no passkey
   ceremony can run without it. The module only calls the API and posts the result; challenge
   creation, verification and every decision stay on the server. Without JavaScript the page shows
   that passkeys need JavaScript and, where the ceremony allows it, the one-time-code alternative.
4. **Social and TOTP settings ceremonies.** `auth/app/settings/{totps,apples,googles}` and the
   Google/Apple sign-up confirmations (Apple and Google display screens are a separate decision; see
   the cleanup round 2 report). Access owns only its own pages: the start of social sign-in is a
   POST form, and the provider callback (including Apple's `form_post`) is handled on the server;
   neither needs JavaScript from Access. What Apple's and Google's own pages do in between belongs
   to the providers and is outside Access's control.
5. **Removal.** Delete `inertia_rails`, `@inertiajs/*`, Inertia layouts, `src/pages/**` for Access,
   `surface_inertia_page`, `inertia_clear_history` and their tests; add a static guard that Access
   renders no Inertia.

## Rules for every batch

- Read AGENTS.md, DESIGN.md, `generic/controllers.mdc`, `generic/no-compatibility-layer.mdc`,
  `generic/no-flash-messages.mdc`, `docs/architecture/i18n.md` before editing.
- Keep every security check and its order (CSRF, rate limits, Turnstile, flow binding, step-up).
  Behavior changes only in rendering.
- Tests per converted screen: success, refusal, missing or stale state, back/forward/reload after
  completion, no-JavaScript submit where the ceremony allows it.
- Never edit `config/credentials/*.yml.enc`. Record each batch in `evidence/`.

## Coordination

- The per-tab flow handle (`adr/browser-flow-handle-per-tab.md`) will change how these screens carry
  state. Convert rendering first, keep the current state handling, and leave the flow-handle change
  to its own task, unless a batch touches the same code anyway.
- If Access ceremonies move or change while Governance takes over Identity data, re-check the
  inventory before each batch.
