# Unauthenticated Flow Review — Ordered Work Order Completion

This record completes the requested pass for
`plans/2026-11-13-anonymous-session-and-unauthenticated-flows-work-order.md`. The implementation and
detailed adversarial history were already present in this worktree and are recorded in
`evidence/2026-11-13-unauthenticated-flows-UF31.md` and
`evidence/2026-11-13-unauthenticated-flows-X4H2.md`; this pass revalidated the affected behavior
after the preceding ordered work items.

## Revision and worktree

- Repository: Access, branch `feature`.
- `git rev-parse HEAD`: `727cdb560d1a55d32b14ed484d34abeda6742a61`.
- The worktree had 341 changed paths before this evidence file was added. Existing changes were
  preserved and affect the results. No commit or push was made.
- `git status --short -- config/credentials` returned no changes. No credential file was read or
  edited.
- This revalidation pass changed no application source, route, schema, migration, or CI file; it
  added this evidence record. The earlier logout implementation and owning-document changes remain
  as described below.
- `git diff --check`: passed.

## A. Current flow inventory

| Flow                                                                                             | Current behavior                                                                                                                                                                                                                                                                                                                            | Boundary and disposition                                                                                                                                           |
| ------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| APP/ORG sign-in, sign-up, recovery, email/telephone OTP, passkey, step-up, and social ceremonies | Identity and credential entry paths fail closed through explicit unavailable responses. Recovery has no mounted Access flow. Unsafe sign-up POSTs are still rejected by Rails CSRF before the unavailable response.                                                                                                                         | Identity, credentials, account data, and their persistence belong to Governance. Do not restore an Access fallback before the approved Governance contract exists. |
| APP/ORG OIDC authorization start, results, cancellation, and social callbacks                    | Public browser entry and callback paths fail closed; they are not converted into the web-form flow pattern. OIDC protocol endpoints retain their distinct protocol checks.                                                                                                                                                                  | Keep OAuth/OIDC `state`, `nonce`, PKCE, PAR, redirect URI, and callback checks separate from form-flow state.                                                      |
| Visa APP/ORG OIDC logout                                                                         | Request intake stages a short-lived pending request in the host-only Rails session. A CSRF-protected POST confirms the logout. Exact retries and the context-only continuation preserve the original request; a distinct sequential request is refused without stopping authority. Completion uses the existing one-use server-side notice. | Active browser flow. Current device, grant, registered return URI, `state`, locale, and legacy return-region context remain bound to the pending request.          |
| Visa token, userinfo, revocation, refresh/check, and DBSC endpoints                              | These retain their own protocol credentials and device/session proofs.                                                                                                                                                                                                                                                                      | Authenticated protocol boundaries, not anonymous browser-flow state.                                                                                               |

The authentication mode inventory remains `:bare`, `:deny_all`, `:guest`, `:private`, and `:open`.
The surveyed active Auth controllers use `:bare`/`:deny_all`; Visa `:open` endpoints still perform
their own protocol or confirmation checks. Owning a flow is not proof of identity.

The plan's symbol inventory was checked against the current `app/`, `lib/`, and `test/` trees:

| Symbol                                                                                                      | Observation and current meaning                                                                                                                                                                                                                                       |
| ----------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `SignUpSessionState`, `SignUpStateMachine`, `ClientSignUpFlow`, `checkpoint_version`, and `with_cycle_lock` | Present. They are retained internal flow/state and concurrency machinery; their presence does not make the unavailable public sign-up endpoints active.                                                                                                               |
| `SocialAuth` and `AUTHENTICATION_MODE`                                                                      | Present. `SocialAuth` remains in the retained social callback/error code; `AUTHENTICATION_MODE` is the controller boundary declaration used by `AuthenticationBase`, not proof of an authenticated actor. The mounted social entry/callback paths remain unavailable. |
| `SignUpSequenceControllerSupport`                                                                           | Absent. No shared sign-up sequence controller is mounted; the current public entry handlers fail closed.                                                                                                                                                              |
| `VisitorSignUpFlow`                                                                                         | Absent. The current tree has no visitor-specific sign-up flow or public route; `:guest` remains a recognized mode but no active controller in the inventory declares it.                                                                                              |
| `SignUp::ParticipantPolicy`, `SignUp::RequirementPolicy`, `SignUp::FinalizationPolicy`                      | Absent. No active Access sign-up ceremony invokes these policies. Account and identity finalization remains outside Access under the accepted split boundary.                                                                                                         |

These statements describe the current code and route map. They do not claim that absence itself is a
historical deletion reason or propose rebuilding those components.

## B. Adversarial findings and disposition

- **Medium / P2 — sequential logout request-context mix-up: fixed.** A second request sharing a
  browser session could previously reuse the first tab's pending confirmation when only the device
  matched. The current guard compares the resolved client, grant, return URI, OIDC `state`, locale,
  and legacy return-region context. A mismatch returns 403 and leaves pending state and OP authority
  unchanged. The exact retry and approved context-only continuation remain accepted.
- **Medium / P2 — simultaneous conflicting first logout requests: reproduced, unresolved.** Two
  concurrent requests starting from the same cookie before a pending response reaches the browser
  can each establish their own context. The earlier non-transactional experiment used separate
  PostgreSQL connections and is detailed in UF31. Correct per-tab isolation needs a persistent flow
  handle and associated route/form/data-shape changes under `adr/browser-flow-handle-per-tab.md`.
  This work order requires approval before a migration that changes existing data; no schema
  contract was approved here. Preserve the sequential guard and track the concurrent race as a
  follow-up rather than claiming it is solved.
- **Retired ceremonies: fail closed.** No local stub, silent fallback, or test-only production path
  was added to replace Governance lookups.
- **Protocol and browser boundaries:** CSRF, OIDC protocol state, host-only cookies, and existing
  return URI validation remain separate controls. No shared cookie or GET business token was added.

## C. Changes represented by the existing worktree

The earlier in-scope implementation changed `app/controllers/concerns/sign_oidc_logout.rb` and
`test/integration/oidc_current_device_logout_test.rb` to reject sequential request-context changes
and preserve the original pending confirmation. It added no logout schema, migration, model,
callback, session-store, or route change. The added APP/ORG cases exercise exact retries, the
approved continuation, altered `state`, a different client/return pair, preserved pending state, and
the absence of an authority stop.

The latest test-only correction is in `test/controllers/auth/app/sign_up_csrf_failure_test.rb`: it
enables and restores forgery protection on the controller that owns the callback and asserts that an
unsafe telephone sign-up POST receives 422 before the unavailable response. It adds no test-only
production branch.

This ordered completion pass made no further source changes. No account, sign-up, or credential
finalization behavior was rebuilt in Access.

## D. Tests and verification

- **Red recorded during the earlier TDD change:** the APP/ORG sequential logout regressions first
  expected 403 and received 200; after the guard was added they passed. The CSRF follow-up's earlier
  full-suite observation was expected 422 and received 503 under test-order-dependent controller
  protection. The current test restores protection on the concrete handler and passed below.
- **Fresh related regression selection:**
  `env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test bin/rails test` with the 14 selected
  logout, unavailable ceremony, social entry/start, authentication-mode, identity-boundary, and CSRF
  test files — 133 runs, 1,599 assertions, 0 failures, 0 errors, 0 skips.
- **Fresh scoped RuboCop:** `app/controllers/concerns/sign_oidc_logout.rb`,
  `test/integration/oidc_current_device_logout_test.rb`, and
  `test/controllers/auth/app/sign_up_csrf_failure_test.rb` — 3 files, no offenses.
- **Fresh Zeitwerk:**
  `env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test bin/rails zeitwerk:check` — passed
  (`All is good!`).
- **Browser smoke:** `bin/rails test:system` with the configured local Playwright CLI, system
  Chromium, and one worker — 2 runs, 6 assertions, no failures/errors/skips. The only system test
  file covers public-surface smoke navigation, not logout; it does not establish logout-specific
  browser behavior.
- **Full Rails suite:** the latest post-PS256 full run is recorded in
  `evidence/2026-11-13-access-ps256-workorder-recheck-E6N4.md`: 5,695 runs, 37,008 assertions, 100
  failures, 102 errors, 0 skips. The worktree was dirty, so these failures are not attributed solely
  to this flow work or classified as a clean-baseline failure set. Coverage for the whole dirty run
  was line 91.36%, branch 65.55%, and all-method 91.03%; no coverage percentage is claimed for the
  changed logout paths.
- Current static-check context is in `evidence/2026-11-13-ci-static-checks-source-switch-D8K4.md`:
  full RuboCop reported 68 findings; ERB lint passed 541 files; DatabaseConsistency 3.1.2 reported
  76 finding lines / 83 grouped offenses; `bun run check` still has four Playwright `Page` type
  errors. These checks were not rerun in this controller-focused revalidation, and no findings were
  suppressed or fixed here.
- Test setup printed its existing test-database catalog, including `test_queue_db`; no Solid Queue
  source, schema, migration, configuration, or operations setting was changed.

## E. Residual risks and handoffs

- Concurrent conflicting first logout requests remain a real race until the accepted per-tab handle
  receives an approved persistent contract and migration. This work order did not authorize that
  schema change.
- Access sign-in, sign-up, recovery, credentials, social identity, and authorization ceremonies
  remain unavailable pending Governance's lookup and handoff contracts. Stage 1–3 Jump design
  evidence is in `evidence/2026-11-13-jump-front-channel-stage-1-3-current-K3N8.md`; it identifies
  missing Governance/Jump origins, delegation decisions, key profile, payload sizing, and browser
  pull boundaries. No fallback was implemented.
- Full Rails, repository-wide RuboCop, DatabaseConsistency, and JavaScript checks are not all green
  in the dirty tree. The available evidence does not establish a clean baseline for the full suite.
- No logout-specific system test exists. The system smoke result above is limited to public
  navigation and liveness.

## F. Owning documentation and boundaries

The earlier implementation amended the existing sign-out ADR, `docs/checklists/sign-out.md`,
`docs/security/logout-sequence.md`, `docs/security/logout-session-management.md`,
`docs/mermaid/idp-state-machine-transition-inventory.md`, and
`docs/mermaid/idp-shared-oidc-logout-session.mmd`. No duplicate ADR was created. The Jump handoff
design remains in the existing pure-OpenID-Provider ADR and is not runtime implementation approval.

No credentials, external repository, production/shared database, route, CI file, or Solid Queue
implementation was changed for this revalidation. No commit or push was made.
