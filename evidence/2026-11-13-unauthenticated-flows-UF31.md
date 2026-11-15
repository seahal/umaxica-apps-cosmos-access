# Unauthenticated Flow Review and Logout Request Binding

Work began on 2026-11-12 and verification completed on 2026-11-13 for
`plans/2026-11-13-anonymous-session-and-unauthenticated-flows-work-order.md`.

## Revision and worktree

- Repository: Access (`/home/global/workspace`), branch `feature`.
- `git rev-parse HEAD`: `727cdb560d1a55d32b14ed484d34abeda6742a61`.
- The worktree was already extensively modified and uncommitted by earlier authorized work. This
  review describes that dirty tree, not HEAD alone; all unrelated changes and deletions were
  preserved.
- No commit or push was made. No `config/credentials/*.yml.enc` file changed.
- This item changed the Visa logout concern, its integration test, the owning logout ADR, the
  sign-out checklist, logout security docs, the IdP transition inventory/diagram, and this evidence.
  It changed no route, model, schema, migration, database configuration, session-store setting, or
  CI file.

## Stage 1 — Current flow inventory

This is the state observed before implementation for this item. The active Access browser ceremony
is Visa OIDC logout; the Cosmos split has made the former APP/ORG identity ceremonies unavailable.

| Flow                                               | Current route behavior and authority                                                                                                                                                                          | Browser/session state                                                                                                                                                                                   | Disposition                                                                                                                           |
| -------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------- |
| APP/ORG sign-in and sign-up                        | Credential entry, OTP, passkey, secret, step-up, social entry/callback, and authorization start routes resolve to realm `UnavailableCeremoniesController`, returning 503 with `Referrer-Policy: no-referrer`. | Older flow models and services remain in the repository but these routes cannot enter them.                                                                                                             | Do not restore or harden retired Access ceremonies. Identity, credential, and persistence behavior belongs to the Governance handoff. |
| Account recovery                                   | No recovery route or controller is mounted in `config/routes/auth.rb` or `config/routes/visa.rb`.                                                                                                             | None.                                                                                                                                                                                                   | No active Access recovery flow.                                                                                                       |
| APP/ORG OIDC authorization start/result            | `/oauth/authorize`, `/oidc/result`, cancellation, and switch paths resolve to the Visa unavailable controller. OAuth token exchange remains a separate POST protocol endpoint.                                | No active Access authorization-code browser flow. Retained transaction models do not establish a mounted flow.                                                                                          | Preserve explicit 503 until Governance integration; retain OIDC protocol protections when it is restored.                             |
| Social sign-in callbacks                           | Auth APP/ORG provider entry and callback paths resolve to unavailable handlers.                                                                                                                               | Historical callback state models/services remain without a mounted callback writer.                                                                                                                     | No active Access callback flow; identity lookup is a Governance handoff.                                                              |
| Email/telephone OTP and step-up                    | Routes are mounted only as unavailable handlers.                                                                                                                                                              | OTP and ceremony models/services remain but are unreachable from these public routes.                                                                                                                   | No active Access flow; credential behavior is a Governance handoff.                                                                   |
| APP/ORG OIDC logout                                | `/oidc/logout` GET/POST stages the request; `/oidc/logout/confirmation` is POST-only; `/oidc/logout/completion` is GET-only. Logout commits only after confirmation.                                          | Rails session stores the pending device public ID and optional grant/client/return data, locale/state, with a five-minute expiry. Completion uses an opaque session marker and a one-use Valkey notice. | Active unauthenticated multi-request ceremony; adversarially review and retain existing protections.                                  |
| APP/ORG token, userinfo, revocation, refresh/check | Each endpoint requires its own client assertion, bearer/access/refresh token, or revocation contract. Refresh rotates current root credentials; check is read-only.                                           | No anonymous browser flow.                                                                                                                                                                              | Adjacent authenticated protocol boundaries only; no redesign.                                                                         |
| APP/ORG sensitive admission                        | POST endpoints require the fixed Base client assertion, bearer access token, matching client, active grant, current refresh root, and usable device; validated requests still return 503.                     | Current implementation creates or advances no admission state.                                                                                                                                          | Explicitly fail closed until Governance integration.                                                                                  |
| APP/ORG DBSC registration/verification             | `/edge/v0/token/dbsc` is `:open` at the OP dispatcher but requires a current credential, matching root/device, and signed device proof; writes are locked and transactional.                                  | Challenge and key state live on current root/device records; the cookie carries only the device session identifier.                                                                                     | Authenticated device-binding protocol, not anonymous.                                                                                 |

`AuthenticationBase` supports `:bare`, `:deny_all`, `:guest`, `:private`, and `:open`, and
undeclared actions default to `:deny_all`. Production controllers currently declare `:bare`,
`:deny_all`, and `:open`; none declares `:guest` or `:private`. Visa `:open` endpoints still perform
their own protocol authentication or confirmation checks.
`OpBrowserSessionRequest#enforce_op_boundary_mode!` rejects authority actions not explicitly
declared `:open`; that declaration is not identity proof.

The Rails session store is `:cookie_store`. No anonymous Access account-recovery or credential
issuance flow is active. No sign-up/session framework, new class, table, or migration was
introduced.

## Stage 2 — Adversarial findings and decisions

### UNAUTH-01 — Medium severity, P2 priority — pending logout context was not request-bound

- **Precondition:** a browser already had an authenticated Visa device and a valid pending logout;
  another tab/request on that browser session submitted a distinct valid logout request for the same
  device before confirmation.
- **Impact:** the old guard checked only the device public ID and rendered the first tab's
  confirmation for a distinct request. The second request's client, return URI, and OIDC state could
  be confused with the first request. GET did not stop authority; the confirmation POST remained
  CSRF-protected, and the user still had to confirm. This was a request-context mix-up, not an
  unauthenticated authority-stop bypass.
- **Existing defenses:** device binding, five-minute expiry, grant/client/return validation at
  intake, POST-only CSRF-protected confirmation, and current device revalidation before stopping
  authority. None compared a second request with the pending request.
- **Decision:** fix in Access. Keep one pending request per browser session; accept an exact
  resolved request retry or the existing context-only redirect continuation and reject a distinct
  sequential request with HTTP 403 without replacing the pending request or changing OP authority.
- **Verification:** the new APP and ORG regression cases failed before the change (two failures:
  expected 403, got 200) and passed after it.

Other reviewed classes did not establish a new active-flow defect in this item: retired sign-in,
sign-up, recovery, OTP, social, and authorization flows are unavailable; logout identifiers are
loaded from the current device-bound session rather than accepted as authority from a request
identifier; confirmation is POST-only and CSRF-protected; return URIs are registry-validated and
redirect through Jump; and the logout completion notice is one-use and server-side. Existing tests
cover stale device, changed device, CSRF, retry, unknown commit, stop failure, and post-commit
presentation failure. No change was made to these contracts.

### Residual — simultaneous conflicting first requests (verified, not fixed)

A temporary non-transactional integration experiment sent two requests from threads holding distinct
PostgreSQL connections, both starting from the same old authenticated browser cookie and no pending
Rails session value. Each request used a different registered client and OIDC state. Both returned
303 and independently serialized their own pending context; no authority stop occurred. The test
asserted distinct PostgreSQL backend PIDs. After the run, the temporary test file was removed and
queries confirmed that its token and device rows were cleaned up.

This demonstrates that sequential mismatch rejection does not serialize simultaneous first requests.
Real tabs share the Rails `:cookie_store` cookie, so the last response cookie can determine the
context used by either continuation. No permanent test was retained that expects both conflicting
requests to succeed, because that would codify the known race as intended behavior.

The accepted `adr/browser-flow-handle-per-tab.md` applies to sign-out and specifies the direction:
server-side per-tab flow records, a Rails-session browser binding, and a page-carried public flow
handle with a versioned transition. Implementing it for both Visa realms requires a persistent data
shape and migrations in the OP databases, plus route/form changes. The current anonymous-flow work
order says to stop an item when its fix requires an out-of-scope schema or contract change. The
decision is therefore to leave simultaneous per-tab isolation as a follow-up to that accepted ADR;
the present implementation claims only sequential conflict refusal.

## Stage 3/4 — TDD change

The added integration test runs for both APP and ORG. It creates a current device, submits a valid
first request with registered client, return URI, and state, then verifies that the canonical
`ri`/optional-`lx` redirect continuation and exact retry render the original confirmation. A changed
state and a different registered client/return pair each receive 403; the original session payload
is preserved, no authority-stop row is added, and the root/device remain active.

The production concern now compares the pending device, resolved client, grant, registered return
URI, OIDC `state`, `ui_locales`, and legacy return-region claim with a repeated request. A separate
continuation predicate accepts only a no-hint request whose query contains `ri` and optional `lx`
and no OIDC protocol parameters; it renders the pending request without replacing stored values.
Mismatches use the existing generic forbidden response.

No model, DB constraint, migration, callback, session store, route, or configuration was added. The
new test exercises accepted continuation, accepted exact retry, rejected changed state, rejected
changed client/return, preserved pending state, and no authority mutation. Numerical line coverage
was not measured; no coverage percentage is claimed.

## Documentation updated

- `adr/first-party-sign-out-op-commit-and-backchannel-logout-for-separated-rp-stores.md` — added an
  implementation clarification to the existing ADR; no duplicate ADR was created.
- `docs/checklists/sign-out.md` — added SIGNOUT-10 for pending request binding.
- `docs/security/logout-sequence.md` and `docs/security/logout-session-management.md` — documented
  exact retry, context-only continuation, sequential conflict refusal, and the cookie-session
  concurrency limit.
- `docs/mermaid/idp-state-machine-transition-inventory.md` and
  `docs/mermaid/idp-shared-oidc-logout-session.mmd` — recorded the transition behavior.

## Verification

| Check                               | Result                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Red regression selection            | 2 APP/ORG failures before implementation: expected 403, got 200.                                                                                                                                                                                                                                                                                                                                                                            |
| Green regression selection          | 2 runs, 34 assertions, 0 failures, 0 errors, 0 skips.                                                                                                                                                                                                                                                                                                                                                                                       |
| Concurrent-request characterization | Temporary test: 1 run, 7 assertions, 0 failures/errors/skips; two threads reported distinct PostgreSQL backend PIDs and both conflicting requests returned 303. It was removed rather than retained as an assertion of the unresolved behavior. Test-created token/device rows were confirmed absent afterward.                                                                                                                             |
| Related regression selection        | `oidc_current_device_logout_test.rb`, `op_existing_session_logout_test.rb`, `oidc_logout_realm_acceptance_test.rb`, `oidc_logout_enqueue_failure_test.rb`, `end_session_request_test.rb`, `logout_request_test.rb`, and `authentication_mode_inventory_test.rb`: 101 runs, 954 assertions, 0 failures, 0 errors, 0 skips.                                                                                                                   |
| Changed-file RuboCop                | `app/controllers/concerns/sign_oidc_logout.rb` and `test/integration/oidc_current_device_logout_test.rb`: passed, 2 files, no offenses.                                                                                                                                                                                                                                                                                                     |
| Full RuboCop                        | Exit 1; 2,012 files inspected, 61 offenses, 50 autocorrectable. These are repository-wide dirty-tree offenses; the two changed Ruby files pass the scoped check.                                                                                                                                                                                                                                                                            |
| `bin/rails zeitwerk:check`          | Passed: all constants eager-load cleanly. Existing MessagePack load-hook diagnostics appeared.                                                                                                                                                                                                                                                                                                                                              |
| `bundle exec erb_lint --lint-all`   | Passed: 541 files, no errors. The parser emitted a Ruby 3.3 grammar / Ruby 4.0 runtime compatibility notice.                                                                                                                                                                                                                                                                                                                                |
| `bundle exec database_consistency`  | Exit 1, no configuration file supplied; current run produced 76 finding lines (83 grouped offenses), matching the official-gem baseline recorded in `evidence/2026-11-12-ci-static-checks-zero-N4K7.md`. Findings concern existing model dependent-destroy associations and were not changed in this controller/session-only item.                                                                                                          |
| `bun run check`                     | Exit 1 at Oxlint: four existing `TS2322` nested/top-level Playwright `Page` type mismatches in unchanged `e2e/ui-components-acceptance.spec.ts`, `e2e/ui-erb-presentation.spec.ts`, `e2e/ui-foundations.spec.ts`, and `e2e/ui-presentation.spec.ts`; same issue is recorded in the earlier static-check evidence.                                                                                                                           |
| Full `bin/rails test`               | Exit 1: 5,585 runs, 35,261 assertions, 103 failures, 145 errors, 0 skips. The prior PS256 evidence reported 5,583 runs, 35,228 assertions, 95 failures, 152 errors. This is a dirty-tree comparison, not a clean baseline; the aggregate delta is not attributed solely to this fix. Failures include old expectations for retired sign-in/503 behavior, removed models, and stale source paths. The focused changed-flow selection passes. |
| `bin/rails test:system`             | Passed after setting the documented Playwright CLI path and installed `/usr/bin/chromium`: 2 runs, 6 assertions, 0 failures/errors/skips. Initial setup attempts established that the Playwright-managed browser was absent; no dependency was downloaded. Existing system tests are public-surface smoke tests, not logout-specific browser coverage.                                                                                      |
| `git diff --check`                  | Passed.                                                                                                                                                                                                                                                                                                                                                                                                                                     |

Test database setup printed the existing local test catalog, including `test_queue_db`, as part of
the shared Rake preparation task. No Solid Queue source, schema, migration, or configuration was
edited. The retired database names in a stale shell allow-list were unset for test commands; no
retired or production database was dropped or modified. No test database cleanup or shared-data
deletion was performed beyond the repository's normal isolated test setup.

## Residuals and follow-up

- Simultaneous first requests using the same cookie-backed Rails session were experimentally shown
  to race. Per-tab request identity requires the accepted flow-handle design and new persistent flow
  records; no GET flow handle or new persistence was added in this bounded item.
- The full Rails suite, full RuboCop, DatabaseConsistency, and JavaScript aggregate check remain
  non-green for the recorded repository-wide/pre-existing issues. No failure was suppressed or fixed
  outside this item's scope.
- Governance owns the identity, credential, sign-in, sign-up, OTP, social, recovery, and
  authorization flows that are explicitly unavailable in Access. Do not restore those Access routes
  before their approved Governance handoff exists.
- The existing authentication mode and protocol boundaries remain unchanged. No credentials, keys,
  external repositories, production services, or external databases were accessed or modified.
