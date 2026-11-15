# Unauthenticated Flow Review — Current Verification

## Revision and worktree

- Repository: Access (`/home/global/workspace`), branch `feature`.
- `git rev-parse HEAD`: `727cdb560d1a55d32b14ed484d34abeda6742a61`.
- The worktree is dirty: 112 modified/staged paths, 68 deleted paths, and 18 untracked paths (198
  total). Existing changes were preserved; they affect all results below. No commit or push was
  made.
- This follow-up completes verification for
  `plans/2026-11-13-anonymous-session-and-unauthenticated-flows-work-order.md`. The detailed
  inventory, adversarial findings, logout TDD change, and owning-document updates are recorded in
  `evidence/2026-11-13-unauthenticated-flows-UF31.md`.
- The current pass made one test-only correction in
  `test/controllers/auth/app/sign_up_csrf_failure_test.rb`; no production behavior, route, schema,
  migration, database configuration, CI file, or Solid Queue implementation changed here.

## A. Current flow state

| Flow                                                                                            | Current Access behavior                                                                                                                                                                                                 | Disposition                                                                                             |
| ----------------------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------- |
| APP/ORG sign-in, sign-up, recovery, email/telephone OTP, step-up, passkey and social ceremonies | Identity/credential routes are absent or resolve to an explicit 503 unavailable handler. Recovery has no mounted Access flow.                                                                                           | Keep unavailable until the Governance contract exists; do not recreate identity persistence in Access.  |
| APP/ORG OIDC authorization start/result and social callbacks                                    | Browser entry/callback routes fail closed. OIDC protocol endpoints remain distinct and retain protocol controls.                                                                                                        | Governance handoff item; do not convert `state`, `nonce`, PKCE, PAR, or callbacks into form-flow state. |
| Visa OIDC logout                                                                                | Staged request is held in the host-only Rails session and confirmed by CSRF-protected POST. Exact retries and the approved redirect continuation retain the original context; a distinct sequential request is refused. | Active flow, with the request-binding fix and docs recorded in UF31.                                    |
| APP/ORG Visa token, userinfo, revocation, refresh/check and DBSC                                | Not anonymous browser ceremonies; protocol-specific credentials, current session/device checks, and proof remain required.                                                                                              | Outside this flow redesign.                                                                             |

The supported authentication modes are `:bare`, `:deny_all`, `:guest`, `:private`, and `:open`; the
observed active Auth controllers use `:bare`/`:deny_all`, and the surveyed Visa `:open` routes
perform their own protocol or confirmation checks. No active controller declared `:guest` or
`:private` in the inventory. Owning a flow is not identity proof.

## B. Adversarial findings and decisions

- **Medium / P2 — sequential logout request-context mix-up:** fixed in Access. Pending logout is
  compared against device, resolved client/grant, registered return URI, OIDC state, locale, and
  return-region context. A distinct request receives 403 and does not replace pending state or stop
  authority. APP and ORG regression coverage is recorded in UF31.
- **Medium / P2 — simultaneous conflicting first logout requests:** reproduced with two threads on
  separate PostgreSQL connections in the earlier review. Both can establish a pending request from
  the same old cookie before either response is received. Preventing this requires the accepted
  per-tab flow handle to be persisted and propagated through logout routes/forms, including a schema
  change. That data shape was not authorized in this item, so the risk remains explicitly open; the
  sequential guard does not claim to solve it.
- Retired Access identity flows remain unavailable. Their missing Governance lookup/ownership
  contract is not replaced with a local fallback or stub.
- OAuth/OIDC CSRF, protocol state, callback, and cookie boundaries remain independently enforced;
  the targeted unavailable and Social entry tests verify unsafe POSTs are refused before any 503
  handler response.

## C. Changes

Earlier work for this plan changed the existing `SignOidcLogout` concern and its integration tests,
then amended the owning logout ADR, sign-out checklist, logout security docs, and IdP transition
inventory/diagram. It added no schema, model, callback, route, session-store setting, or CI change;
see UF31 for exact paths and behavior.

This pass corrected the CSRF regression test to set and restore
`Auth::App::UnavailableCeremoniesController.allow_forgery_protection`, the controller that owns the
request callback. The previous test toggled only `ActionController::Base`; under a different test
order, a controller-specific setting could leave the request protected by the subclass setting
instead. The test continues to assert that an unsafe telephone sign-up POST is rejected with Rails'
422 response before the explicit unavailable response. It adds no test-only production branch.

No current-doc changes were needed for this test-scoping correction. Stage 1–3 handoff design is
recorded separately in `evidence/2026-11-13-jump-front-channel-stage-1-3-Q7M2.md`; its unresolved
contract decisions remain handoff items, not implementation.

## D. Tests and verification

- **Red observed before the test correction:** the earlier full-suite run recorded
  `Auth::App::SignUpCsrfFailureTest#test_a_telephone_sign-up_submission_without_a_token_is_refused_before_the_unavailable_response`
  as expected 422 / actual 503. The test had passed in isolation, indicating test-order-sensitive
  controller configuration. This Red was observed in the existing full-suite evidence, not
  manufactured by weakening an assertion.
- **Green, related selection:** 138 runs, 1,584 assertions, 0 failures, 0 errors, 0 skips. This
  included OIDC current-device logout, existing-session logout, realm acceptance, enqueue failure,
  end-session parsing, logout parsing, unavailable ceremony, sign-up CSRF, Social entry/start, route
  naming, identity-authority boundary, and authentication-mode inventory tests.
- **Green, narrower unavailable/Social selection:** 19 runs, 439 assertions, 0 failures, 0 errors, 0
  skips.
- `bin/rubocop test/controllers/auth/app/sign_up_csrf_failure_test.rb`: passed, one file, no
  offenses. `git diff --check`: passed.
- `bin/rails zeitwerk:check`: passed (`All is good!`). Rails emitted its existing MessagePack load
  hook diagnostic during boot.
- Full `bin/rails test`: completed with 5,584 runs, 35,358 assertions, 95 failures, 137 errors, 0
  skips. This dirty-tree run is not green. Errors/failures observed include missing constants in
  older model/service tests, tests expecting removed Preference routes or controllers, and stale
  PS256-era expectations. The dirty tree has no clean-HEAD baseline, so the aggregate result is not
  attributed solely to this plan or labeled entirely pre-existing. The focused flow selection
  passed.
- Test preparation initially rejected a stale inherited `POSTGRESQL_TEST_PREPARE_DATABASES` list
  containing removed database names before tests started. Runs were then given the current test
  database list from `config/ci.rb` as a command-scoped environment value; no configuration file was
  changed. One initial pair of parallel test preparations hit
  `ActiveRecord::ConcurrentMigrationError`; rerunning test preparation serially succeeded. The
  existing preparation scope listed `test_queue_db`; no Solid Queue source, migrations,
  configuration, or operational settings were edited, and no pending queue migration output
  appeared.
- Coverage percentages were not measured. No database shape changed in this follow-up. The latest
  official-gem DatabaseConsistency and static-check results are in
  `evidence/2026-11-13-ci-static-switch-V2K9.md`; this pass did not change their inputs.

## E. Residual risks and follow-ups

- Simultaneous first logout requests still race. Implement the already accepted per-tab flow-handle
  contract only after its persistent shape, transition ownership, and migration/data impact are
  approved; keep the current sequential rejection meanwhile.
- Access sign-in, sign-up, credentials, social identity, recovery, and authority freshness remain
  unavailable until the Governance lookup/handoff contract and implementation exist.
- The full Rails suite remains non-green (95 failures, 137 errors). Failure classification is
  incomplete against a clean baseline; the exact full output should be reviewed by the owners of
  removed models/routes, current PS256 behavior, and static-invariant tests.
- No browser-system test was rerun in this follow-up. Previous UF31 evidence has a passing system
  smoke test, but it is not logout-specific browser verification.

## F. Documentation and boundaries

- Existing owning-doc updates:
  `adr/first-party-sign-out-op-commit-and-backchannel-logout-for-separated-rp-stores.md`,
  `docs/checklists/sign-out.md`, `docs/security/logout-sequence.md`,
  `docs/security/logout-session-management.md`,
  `docs/mermaid/idp-state-machine-transition-inventory.md`, and
  `docs/mermaid/idp-shared-oidc-logout-session.mmd` (detailed in UF31).
- No duplicate ADR was created. The Stage 3 handoff proposal stays in the existing
  `adr/access-is-a-pure-openid-provider.md` and remains explicitly unapproved for runtime
  implementation.
- `config/credentials/`, routes, `config/database.yml`, and `config/ci.rb` have no worktree changes
  at this capture. Credential files were not read or edited. No commit, push, deployment, external
  repository fetch, or production/shared-database operation occurred.
