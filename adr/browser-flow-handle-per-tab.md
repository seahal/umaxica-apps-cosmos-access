# Browser Flows: Per-Tab Flow Handle in the Page, Browser Binding in the Rails Session (2026-11-10)

## Status

Accepted (owner, 2026-11-10). Applies to Access and Governance, the two repositories that run
pre-authentication flows (sign-in, sign-up, sign-out, credential ceremonies, account registration).
Implementation is follow-up work; it replaces existing flow-state code without a compatibility
layer.

Supersedes `specs/browser-flow-state-cookies/spec.md` (purpose-specific encrypted cookies, "one flow
per browser and purpose") and the browser-side part of D-155 in
`plans/archive/0002-authentication-cycle-2026-10/requirements-and-decisions.md` for Access and
Governance flows. Server-side state machines and their transition writers stay; only how a request
finds and proves its flow changes.

## Context

Flow state has been carried on the browser side as one value per browser: first in the Rails
session, then (per the superseded spec) in one encrypted cookie per purpose. All tabs of a browser
share that value, so tabs compete for it. Each flow then needed its own rules for which tab wins
("newer wins at start", "first to the checkpoint wins"), for refusing the loser, and for where the
loser restarts. Observed costs:

- leftover state from a finished flow refused a new one ("この画面は古くなっています", 2026-11-06);
- an earlier tab could finish OTP or passkey steps and be refused only at the RP callback (D-155);
- about 60 session keys, an estimated cookie header of up to 23 KB, and two-tab cases mostly
  unverified (FLOW-5 partial, A43-9 not run).

Two products solved the same problem the same way. Keycloak changed in 2017 from one authentication
session per browser to a root session per browser holding one authentication session per tab, found
by a `tab_id` in the URL together with the browser cookie, after shared state sent users to the
wrong client. Ory Kratos identifies each self-service flow by an ID in the URL (`?flow=`), keeps the
flow as a server-side record with an expiry, and refuses requests without the browser's CSRF cookie.
OWASP requires sessions to be identified by cookies, never by URL parameters, because URLs leak
through links, logs, history and the Referer header and enable session fixation.

## Decision

1. **The browser is identified by the Rails session; the flow by a handle in the page.** The Rails
   session holds one random browser binding secret (32 bytes, `SecureRandom`). Each flow is a
   server-side record holding an HMAC digest of that secret, never the secret itself. The page (URL
   path or form field) carries the flow handle: the flow's public ID and its version. A handle
   proves nothing on its own; a request proceeds only when the handle's flow is bound to the
   requesting browser's secret. The handle is a room number, the session is the key.
2. **One flow per tab, not per browser.** Every start creates a new flow; starting one never cancels
   or replaces another. In Access a flow starts from one authorization request (one PAR
   `request_uri`), so two tabs opening the same relying party run two separate flows.
3. **Every transition is compare-and-set on the version.** A transition succeeds only if the
   handle's version equals the record's current version; it then increments the version and returns
   a page carrying the new handle. Transitions use the existing state machines and their writers
   (`generic/lifecycle-transition-writers.mdc`).
4. **A stale handle is redirected, not refused.** A version mismatch on a live flow bound to this
   browser (double submit, back button, an old copy of the page) redirects to the flow's current
   step. Only an expired, finished or foreign flow shows the restart guidance, whose link is fixed
   per surface (spec D-12, kept).
5. **`reset_session` ends every flow of the browser.** Sign-in success and sign-out call
   `reset_session` (session fixation defence, OWASP; ASVS 5.0 7.2.4), which discards the binding
   secret, so every other open flow of that browser stops matching. A tab whose flow no longer
   matches gets the restart guidance; restarting from the relying party then completes silently
   through the new OP session. No cross-tab cancellation logic is written.
6. **One shared mechanism, two concerns.** The mechanism is implemented once per repository as:
   - an HTTP concern (controllers): read the handle from the request, load the flow bound to this
     browser, start a flow, and respond to a stale or foreign handle;
   - a model concern (flow records): the public ID, version, binding digest, expiry and the
     compare-and-set transition. Both follow `generic/rails-concerns.mdc`: no inclusion hooks,
     explicit visibility, side effects only through methods the including class calls, no surface
     switching. Controllers do not touch the binding secret or flow handles directly. Access and
     Governance carry the same code; whether to extract a shared gem is decided later.
7. **What stays in the Rails session.** The CSRF token, the browser binding secret, the OmniAuth
   `state` (gem behavior), `inertia_clear_history`, `timezone` and `language`. A static guard test
   fails on any other `session[...]` key. No per-purpose flow cookies.
8. **What never goes into a handle or the page.** Secrets, OTPs, tokens, contact values. Flow pages
   send `Cache-Control: no-store` and `Referrer-Policy: no-referrer`.
9. **Limits are not per flow.** Attempt limits, cooldowns and admission limits stay keyed by
   account, network and browser binding, so opening more tabs does not reset them.
10. **Built in-house; no wizard or flow gem** (owner, 2026-11-10). The mechanism covers a small,
    fixed set of flows: sign-up, sign-in, sign-out, account withdrawal, step-up (two-step
    verification), social sign-in settings and passkey registration. Each flow defines only its step
    sequence; the handle, browser binding, compare-and-set, stale-handle redirect and expiry come
    from the two concerns, and steps and transitions use the existing state machines and their
    writers. No third-party state-machine gem is added alongside them. The withdrawal sequence is
    fixed after the credential-placement proposal for `adr/access-is-a-pure-openid-provider.md` is
    decided.

## Consequences

- Tabs no longer interfere; the "which tab wins" rules and their tests are deleted.
- Most stale-page cases recover by redirect instead of a restart.
- The Rails session stays small; the cookie-size risk disappears.
- Successful sign-in or sign-out in one tab sends other in-progress tabs through one restart.
  Accepted by the owner (2026-11-10): the case arises only after a sign-in succeeded, and the
  restart passes silently through the new OP session.
- Existing in-flight flows restart once at deployment (no compatibility layer).

## Rejected Alternatives

- **A multi-step wizard gem.** `ultra_light_wizard` (0.1.4, beta) builds steps as nested resources
  and appears to save the record before all steps are valid; it has no browser binding or
  compare-and-set. Wicked helps choose which step page to render but leaves state storage, browser
  binding, tab isolation and double-submit protection to the application, so it saves little. No gem
  found combines a page-carried handle, session binding and versioned transitions.
- **Flow ID in the URL as the only identifier** (URL-rewritten sessions). Anyone who learns the URL
  could use the flow; rejected by OWASP and by the owner.
- **One flow per browser** (Rails session or purpose cookies). It is the cause of the tab
  competition described above.
- **Client-side tab coordination as the control** (BroadcastChannel, Service Worker). It may improve
  the display later, but correctness stays on the server; Access uses no Service Worker
  (`docs/backlog/2026-11-10-access-no-service-worker.md`).

## References

- OWASP Session Management Cheat Sheet (session IDs in cookies, not URLs; regenerate on
  authentication):
  https://cheatsheetseries.owasp.org/cheatsheets/Session_Management_Cheat_Sheet.html
- OWASP ASVS 5.0, V7 Session Management (7.1.2, 7.2.3, 7.2.4):
  https://github.com/OWASP/ASVS/blob/master/5.0/en/0x16-V7-Session-Management.md
- Keycloak, per-tab authentication sessions (design discussion, 2017):
  https://lists.jboss.org/pipermail/keycloak-dev/2017-December/010242.html
- Keycloak `RootAuthenticationSessionModel` (authentication sessions keyed by tab ID):
  https://www.keycloak.org/docs-api/latest/javadocs/org/keycloak/sessions/RootAuthenticationSessionModel.html
- Ory Kratos self-service flows (flow ID in the URL, CSRF cookie binding, `expires_at`):
  https://www.ory.com/docs/kratos/self-service
- Rodauth (Ruby; keeps flow state in the session, shared by tabs, so not used as the model):
  https://rodauth.jeremyevans.net/
- Wicked (multi-step controllers; evaluated, not used):
  https://schneems.com/post/18437886598/wizard-ify-your-rails-controllers-with-wicked
- ultra_light_wizard (evaluated, not used): https://github.com/AndyObtiva/ultra_light_wizard

## Work order (Codex; Access first, then Governance)

```
Implement adr/browser-flow-handle-per-tab.md in this repository. Destructive replacement is
approved: no compatibility layer, no migration of in-flight flows; development data may be lost.
No commit.

Read first: the ADR above and its References; AGENTS.md and the rules it requires for
app/controllers/**, app/models/**, app/controllers/concerns/**, test/**, db/*migrate/**
(generic/rails-concerns.mdc, docs/architecture/method-visibility-and-concerns.md,
generic/lifecycle-transition-writers.mdc, generic/no-compatibility-layer.mdc,
project/session-issuance.mdc, generic/absolute-rules.mdc); specs/browser-flow-state-cookies/
spec.md and inventory.md for the current keys being replaced.

1. Model concern for flow records: public ID, version, binding digest (HMAC-SHA256 of the browser
   binding secret with a key from Rails.app.creds), expires_at, finished state; a compare-and-set
   transition (expected version -> next state, version + 1) under a row lock, delegating to the
   existing state machine writers. NOT NULL columns, explicit states (AGENTS.md).
2. HTTP concern for controllers: ensure_browser_binding (creates the secret in the Rails session
   only when a flow starts), start_flow, load_bound_flow (handle from the request; foreign,
   expired or finished -> restart guidance; version mismatch on a live bound flow -> redirect to
   the current step), and the no-store / no-referrer headers. Called explicitly; no inclusion hooks.
3. Move every sign-in, sign-up, sign-out and credential ceremony flow onto the two concerns.
   Start an Access sign-in flow per authorization request (PAR request_uri). Delete the
   superseded code: purpose-cookie work, SignInCycleLocator-style session locators, "newer wins" /
   "first to checkpoint" logic, and session keys outside the ADR's decision 7.
4. reset_session on sign-in success and on sign-out (verify current behavior; keep the existing
   order of security checks).
5. Static guard test: session[...] keys limited to the ADR's list.
6. Tests at public HTTP boundaries: two tabs, same RP, both complete in either order; double
   submit; back button; foreign browser with a copied handle is refused; expired flow; sign-in in
   tab A then action in tab B gets restart guidance; sign-out ends all flows; limits are not reset
   by opening tabs.
7. Mark specs/browser-flow-state-cookies/spec.md as superseded by this ADR. Run bin/rails test,
   test/security, bin/rubocop, erb_lint, bun run check. Record evidence/ with the references above.
Report deleted code, the flows moved, and anything kept with the reason.
```
