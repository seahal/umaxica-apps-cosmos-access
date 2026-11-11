# Access Route Separation Implementation Notes

## Context

- Original plan: `adr/cosmos-base-surface-decomposition.md`, especially “First Step: Hard Reset”.
- Related decisions: `adr/cosmos-identity-authentication-global-authorization-split.md`,
  `adr/cosmos-common-database-connections.md`, `adr/cosmos-sphere-surfaces-and-rp-independence.md`.
- Related materials: `specs/cosmos-press-route-ownership/spec.md`,
  `docs/backlog/2026-11-08-jwt-key-handling-after-cosmos-split.md`, and
  `plans/2026-11-08-cloudflare-tunnel-split.md`.
- Implementation date: 2026-11-08 through 2026-11-09.
- This note consolidates and supersedes the working record formerly at `tmp/luna.md`.

## Decisions and Boundaries

- Access retains Auth, Visa, and the seven development tools: Mission, Flipper, Blazer, PgHero,
  Swagger, Performance, and Coverband. RP surfaces are outside the remaining Access draw set.
- Preserve OIDC client registrations and configured hosts. This is consistent with the accepted
  decision that Access remains an OP for its registered RPs; route-draw removal does not remove RP
  registrations or host ownership.
- Auth App and Org `/sign/out` routes were removed because they relayed to Base sign-out. Visa OIDC
  logout remains.
- Preserve Auth verification handoff/cancellation routes used by the Auth-owned OIDC step-up flow.
  Remove Base-directed returns and links from Auth/Visa; do not redirect to a substitute surface
  when no OIDC return exists.
- Preserve Auth ceremony-binding handling for both authorization and OIDC step-up transactions. Visa
  App and Org accept the step-up binding confirmation and validate its parent purpose. A Visa
  confirmation must be bound to the matching browser nonce, active attached Auth ceremony session,
  active OP token, actor, and live parent transaction. A foreign actor, expired binding, or redeemed
  replay is refused without confirming the binding.
- The signing-key storage approach, installer/registry/client verification, credentials, development
  database and volumes, external services, and commits are outside this work. The proposed signing
  key management ADR remains unimplemented.

## Implementation Decisions and Observations

- The former `tmp/luna.md` caller inventory classified the cleanup as follows:
  - **Remove route and controller entry points used only for Base round trips:** Auth App/Org sign
    out; Base-only TOTP/settings returns; Base verification handoff, completion and cancellation
    returns; and Base-purpose ceremony-binding confirmation. Subsequent caller tracing showed that
    Auth verification handoff/cancellation routes participate in Auth-owned OIDC step-up, so those
    shared routes remain while their Base-directed returns are removed.
  - **Remove Base links and redirects:** `SurfaceChrome`, `AuthenticationRedirects`, `SocialAuth`,
    Auth App/Org `ApplicationController`, Auth layouts, and
    `app/helpers/auth/org/sign_ups_helper.rb`. Keep OIDC handoffs. Auth-root fallbacks were deferred
    to the later work unit as directed.
  - **Keep routes and remove only Base-directed branches:** Visa App/Org limitations and Auth
    ceremony-binding dispatch. Visa authorization continuation and both OIDC authorization and OIDC
    step-up binding handoffs remain. Unsupported parent purposes use the existing explicit error
    path.
- Relevant caller locations investigated included Auth settings/TOTP controllers, verification
  handoff and cancellation controllers, Auth ceremony-binding controllers, passkey verification,
  sign-up controllers, withdrawal/verification concerns, `SurfaceChrome`, `AuthenticationRedirects`,
  `SocialAuth`, Auth layouts, and sign-up helpers. Searches covered `app/` Ruby, `src/` TypeScript,
  mail templates, `config/`, and `test/`, for both removed named route helpers and literal URLs to
  retired hosts. RP client registrations and host registrations were explicitly retained;
  retired-host negative tests and shared test setup were not classified for deletion by name alone.
- Auth App/Org sign-out relay routes and their relay controllers were removed; the route/security
  tests now assert those routes are absent. Visa logout was retained.
- Auth App/Org root routes, root controllers, root pages and their landing tests were removed to
  keep Auth ceremony-only. The global unknown-host root response remains a JSON 404. Auth chrome
  renders the brand without a link; Visa chrome retains its OIDC logout destination. Tests and
  layout code no longer resolve or import the deleted Auth root pages.
- Base links were removed from Auth/Visa surface chrome, redirect, social-auth and mailer paths.
  Deleted route-helper searches across the remaining Auth, Visa, and mailer code returned no calls.
  The internal method name `oidc_result_base_completion_url` remains, but resolves to a Visa OIDC
  result URL rather than a deleted Base route.
- Visa App and Org Authority now own their lifecycle rather than inheriting Base Authority. Callback
  ordering, conditions, exclusions, rescue handling and layout were compared with the behavior that
  had actually applied to Visa. In particular, Visa Org preserves the former exclusion of the
  second-passkey gate.
- The Org OTP verification link was a Base identity page, not a required Auth OIDC step. The link
  was removed instead of substituting a URL on another host. Delivery coverage checks successful Org
  OTP mail delivery without a `NameError` or the removed URL. No production promotional-mail sender
  was found; promotional unsubscribe concerns were removed from Access mailers.
- The Visa step-up binding integration test initially failed because assigning `session[...]` in the
  test did not put the matching nonce into the request's encrypted Rails session cookie. The test
  now constructs that cookie using the same continuity setup as existing integration coverage.
- The prior working note contained obsolete “pending approval” and “implementation outstanding”
  sections. Owner decisions later resolved both classification questions and authorized the work;
  those stale statements are replaced here by the current disposition.
- A pre-change test baseline is unavailable. A baseline worktree was tried as authorized, but could
  not provide a reliable comparable run. The earlier full-suite aggregate (17,164 runs, 146,002
  assertions, 302 failures, 192 errors) has no saved failure details and is not a passing baseline.

## Step-Up Binding Tests

`test/controllers/visa/app/ceremony_binding_confirmations_controller_test.rb` includes:

- [line 85](../../test/controllers/visa/app/ceremony_binding_confirmations_controller_test.rb#L85):
  `step-up confirmation succeeds only in the matching user's OP session` — a successful Visa
  confirmation continues to the Auth verification handoff.
- [line 96](../../test/controllers/visa/app/ceremony_binding_confirmations_controller_test.rb#L96):
  `step-up confirmation refuses another user's OP session without confirming the binding`.
- [line 118](../../test/controllers/visa/app/ceremony_binding_confirmations_controller_test.rb#L118):
  `step-up confirmation refuses an expired binding`.
- [line 127](../../test/controllers/visa/app/ceremony_binding_confirmations_controller_test.rb#L127):
  `step-up confirmation refuses a redeemed binding replay`.
- [line 143](../../test/controllers/visa/app/ceremony_binding_confirmations_controller_test.rb#L143):
  `authorization and step-up bindings are confirmed against their own parent purposes`.

Related existing coverage includes:

- `test/controllers/auth/step_up_admission_test.rb` — Auth-side OIDC step-up admission and
  verification continuation.
- `test/operations/oidc_step_up_authorization_issuer_test.rb` — issuance attaches the existing live
  grant without establishing a new root login.
- `test/integration/acceptance_wu12_relay_repeat_test.rb` — Visa confirmation handoff replay,
  browser continuity, and confirmation behavior.
- `test/controllers/visa/org/sign/in/limitations_controller_test.rb` — preserved Visa OIDC
  authorization continuation.

## Verification

See `evidence/2026-11-08-visa-step-up-binding-E7K2.md` for the exact HEAD, dirty worktree status,
commands, full-suite outcome and attribution limits. The Visa/Auth/OIDC step-up group passed with 45
tests, and the full `test/security/` suite passed with 147 tests. RuboCop reported no offenses and
Brakeman reported no security warnings. One full Rails suite run completed with 652 failures and
1,020 errors. Its direct deleted-surface test failures are identified in the evidence record; the
remaining failures cannot be compared individually because the pre-change failure details were not
saved. Live-edge/Cloudflare behavior remains unverified.

## Follow-Up

- Reconcile remaining code, views, tests, non-HTTP callers, and database connection configuration
  against the complete split scope before describing the whole Access decomposition as complete.
- Retired-host behavior at a live deployment edge and Cloudflare connector state remain unverified;
  no container or external service was changed for this work.
