# Cosmos Identity Renders Without Inertia (2026-11-08)

## Status

Accepted (2026-11-08), direction only. Conversion order and completion are not decided by this
record.

Scope: the `umaxica-apps-cosmos-identity` repository only. `umaxica-apps-cosmos-global`,
`umaxica-apps-cosmos-regional` and `umaxica-apps-cosmos-press` continue to use Inertia under
`adr/inertia-rails-thin-adapter.md`.

Amended 2026-11-10 (owner): the repository is now `umaxica-apps-cosmos-access`. The primary reason
for removing Inertia from Access is **leakage of sensitive information through browser history**,
stated below as the governing rationale.

## Context

`adr/cosmos-identity-authentication-global-authorization-split.md` limits Identity to ceremony
screens: sign-in, MFA, passkey ceremonies, consent, step-up and sign-out. Identity has few screens
and no dashboard.

Inertia keeps page state in browser history. `adr/inertia-rails-thin-adapter.md` therefore makes
history encryption mandatory and requires every sign-out, withdrawal and step-up cancellation path
to set `session[:inertia_clear_history]` so the next Inertia response clears history. At this
decision that flag is set from at least six controller paths. A path that forgets the flag leaves
pages from the previous session readable in history. This is an easily missed, cross-cutting duty,
and it sits on exactly the screens Identity keeps.

At this decision Inertia renders roughly 130 actions under `auth` and `base`, plus Visa OIDC logout
endpoints. Many `base` screens leave Identity under the split, so their conversion is not Identity
work.

### Primary rationale: sensitive information in browser history (2026-11-10)

Inertia stores each page's props (the data the server sends to render the page) in the browser's
session history (`history.state`) so it can restore pages on back and forward navigation. On Access
those props belong to authentication ceremonies: identifiers such as email addresses and telephone
numbers, ceremony and binding references, step-up and MFA state, error details. After sign-out, or
on a shared or lost device, that data can be read back by navigating back, from the back/forward
cache, or from restored sessions, without any request reaching the server, so server-side session
termination does not remove it.

Inertia's history encryption and `clear_history` reduce this exposure, but only when every
session-ending path remembers to request the clear, and the protection depends on client-side key
handling. A missed path is a silent leak. Server-rendered pages sent with `Cache-Control: no-store`
keep no page data in history beyond the URL, so the risk is removed by construction instead of by
discipline. This is why Access, which holds the most sensitive screens, renders without Inertia.

## Decision

1. Identity renders all screens with Rails defaults: server-rendered ERB views, forms submitted as
   normal requests, and Stimulus only where a ceremony needs browser APIs (for example WebAuthn).
2. Identity does not use `inertia_rails`, `@inertiajs/*`, Inertia pages under `src/pages/`, or the
   `inertia_clear_history` session flag. Every response that ends a session or ceremony relies on
   ordinary navigation and `Cache-Control: no-store` instead of client history clearing.
3. Screens that leave Identity under the split move to their new owner as they are; they are not
   converted to ERB first.
4. Inertia is removed from Identity by deletion, not hidden behind a compatibility layer
   (`generic/no-compatibility-layer.mdc`).

### Back and forward navigation (amended 2026-11-10)

Removing Inertia is necessary but not sufficient. Access must treat browser back and forward
navigation as a security-relevant input on every screen, not only on Inertia pages (owner):

1. **Nothing sensitive is restorable from history.** Every Access response carries
   `Cache-Control: no-store`, which also keeps pages out of the back/forward cache in current
   browsers. Sign-out and withdrawal end with `Clear-Site-Data` where the response allows it.
2. **Nothing sensitive is in a URL.** URLs are kept in history even when pages are not: codes,
   tokens, email addresses, telephone numbers and binding secrets never appear in a path or query
   string. Opaque, short-lived references are acceptable.
3. **Ceremonies are one-way.** State-changing steps use POST followed by a redirect (POST/Redirect/
   GET). A ceremony step that has completed, expired or been cancelled cannot be resumed or
   resubmitted by going back; the server refuses it from its own state and sends the user to a fresh
   start, never to a page that shows the earlier data.
4. **Forward and back cannot cross sessions.** After sign-out or a session change, navigating back
   to an authenticated or in-ceremony URL must fail closed with a fresh request to the server.
5. **Forms do not retain secrets.** One-time codes and passwords use the appropriate `autocomplete`
   values and are never prefilled from earlier submissions.
6. **Verify it.** Acceptance for each Access ceremony includes back, forward and reload after
   completion, cancellation, expiry and sign-out.

### Protocol exceptions to the navigation rules (amended 2026-11-10)

The acceptance check (`evidence/2026-11-10-access-acceptance-H8R4.md`) showed that rules 1 to 3
above, read literally, conflict with OAuth 2.0, OpenID Connect and public metadata. They are
narrowed as follows; everything else in them stands.

- **Rule 1, `no-store`:** public, non-personal resources are exempt and may be cached: JWKS, OpenID
  Connect Discovery, `robots.txt`, `sitemap.xml`, health and revision endpoints. Every response that
  is personal, session-bound or part of a ceremony, including settings pages and social-login
  callbacks, keeps `Cache-Control: no-store`.
- **Rule 2, nothing sensitive in a URL:** values a protocol requires in the URL are exempt when they
  are short-lived, single-use and bound to the client or browser: the OAuth authorization `code`
  (with `state` and `iss`) returned on the redirect URI, and the signed Jump `rt` token. Personal
  data (email addresses, telephone numbers), long-lived tokens and secrets are never in a URL.
- **Rule 3, POST/Redirect/GET:** the OAuth/OpenID Connect authorization endpoint is a GET by
  standard and may create the authorization transaction on GET. Such records expire quickly, grant
  nothing by themselves and are bound to the browser; all other state changes keep
  POST/Redirect/GET.

## Consequences

- The history-clearing duty disappears from Identity; session-ending paths no longer carry a flag
  that every new path must remember.
- Ceremony screens lose client-side page transitions; Identity's small screen count keeps this cost
  low.
- Identity's frontend toolchain shrinks to Vite, Stimulus and CSS; React and Inertia dependencies
  can be removed once no Identity screen uses them.
- The remaining repositories keep `adr/inertia-rails-thin-adapter.md` unchanged, including its
  history-clearing duty.
- Conversion should follow the screen placement decided by the split, so only screens Identity keeps
  are rewritten.

## Final personal-response cache enforcement (2026-11-10)

Auth App settings, the approved Auth App Google/Apple and Auth Org Entra callback paths, and Visa
App/Org authorization responses enforce `private, no-store` at the final response boundary. This
includes early callback redirects, admission refusals and framework exception responses that do not
finish controller callbacks. The boundary matches each configured host and its owned paths; it uses
the same slash normalization as the Rails router without decoding escaped path segments. It changes
caching headers only and preserves the authentication, authorization, CSRF and rate-limit pipeline.
Public metadata and other surfaces retain their existing cache policy.
