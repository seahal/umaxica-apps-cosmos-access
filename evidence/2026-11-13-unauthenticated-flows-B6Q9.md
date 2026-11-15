# Anonymous Session and Unauthenticated Flow Review — Completion Evidence

## Revision and scope

- Repository: Access; branch `feature`; `git rev-parse HEAD`:
  `727cdb560d1a55d32b14ed484d34abeda6742a61`.
- Before this evidence was added, the worktree had 265 changed paths. Existing changes were kept;
  they affect the results below. This review added no application, route, schema, migration,
  configuration, CI, or Solid Queue changes.
- This completes the requested pass over
  `plans/2026-11-13-anonymous-session-and-unauthenticated-flows-work-order.md`. The full inventory,
  original adversarial review, TDD implementation and durable-document changes are recorded in
  `evidence/2026-11-13-unauthenticated-flows-UF31.md`; the CSRF test-order correction is recorded in
  `evidence/2026-11-13-unauthenticated-flows-X4H2.md`.
- No credentials were read or edited. No commit, push, production/shared database operation, or
  external repository fetch occurred.

## A. Current flow inventory

| Flow                                                                                             | Current behavior and state owner                                                                                                                                                         | Decision                                                                                                                                      |
| ------------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------- |
| Sign-in, sign-up, recovery, email/telephone OTP, step-up, passkey and social identity ceremonies | Access identity entry points are absent or use an explicit unavailable response. Access does not retain the Governance-owned identity or credential flow state.                          | Keep unavailable until the Governance lookup/ceremony contract exists; do not add local identity persistence or success stubs.                |
| OIDC authorization start/result and social callbacks                                             | Browser ceremony entries fail closed. OAuth/OIDC `state`, `nonce`, PKCE, PAR, redirect registration and callback checks remain protocol controls.                                        | Preserve these checks independently; route identity work through the future Governance contract.                                              |
| APP/ORG Visa OIDC logout                                                                         | Pending request context lives in the encrypted, host-only Rails cookie session. A CSRF-protected POST confirms it; current device and grant are revalidated before authority is stopped. | Exact retries and the approved context-only redirect continuation may resume the existing request; a different sequential request is refused. |
| Visa token, userinfo, revocation, refresh/check and DBSC                                         | These are protocol-authenticated endpoints rather than anonymous browser ceremonies.                                                                                                     | Leave their proof, device and session checks outside this flow change.                                                                        |

The surveyed flow implementation vocabulary is recorded in UF31: `SignUpSessionState`,
`SignUpStateMachine`, `ClientSignUpFlow`, `checkpoint_version`, `with_cycle_lock`, `SocialAuth`, and
`AUTHENTICATION_MODE` were checked; the named sequence/visitor/policy classes listed as absent in
the work order were confirmed absent. Supported authentication modes are `:bare`, `:deny_all`,
`:guest`, `:private`, and `:open`; active Auth controllers in the reviewed tree use `:bare` or
`:deny_all`, and Visa `:open` routes perform their own protocol/confirmation checks. No active
controller in the recorded inventory declares `:guest` or `:private`. Flow ownership is not proof of
identity.

The Rails session cookie is encrypted, host-only, `HttpOnly`, explicitly `SameSite=Lax`, and
`Secure` outside development/test, with the recorded 14-day session expiry. It is not shared across
surfaces. OIDC protocol state remains governed by its own protocol contracts, not by the logout
form-state behavior.

## B. Findings and disposition

- **Medium / P2 — sequential logout request-context mix-up — fixed.** With a pending logout on the
  browser session, the old guard compared only the device session. A distinct second request could
  reuse the first request's confirmation context. The corrected guard binds device, client, grant,
  registered return URI, OIDC `state`, locale and legacy return-region context. Only an exact retry
  or the constrained `ri`/optional-`lx` continuation is accepted; a distinct request receives 403,
  preserves the pending payload and does not stop authority.
- **Medium / P2 — simultaneous conflicting first requests — reproduced, remains open.** Two requests
  with separate PostgreSQL connections can begin from the same old cookie before either response
  writes its session cookie. Both can establish different pending requests. A cookie-backed Rails
  session cannot serialize this race. The accepted per-tab flow-handle ADR needs persistent flow
  identity and route/form contract changes; this bounded plan did not authorize that schema and
  contract change. The sequential guard makes no claim to prevent this race.
- Retired identity flows remain unavailable; no silent fallback, local identity stub, or identity
  data restoration was introduced.
- OAuth/OIDC protocol state and Rails CSRF remain separate protections. The unsafe telephone sign-up
  request test confirms CSRF rejection occurs before the unavailable handler response.

## C. Implementation and traceability

The earlier implementation changed `app/controllers/concerns/sign_oidc_logout.rb` and
`test/integration/oidc_current_device_logout_test.rb`, then amended the owning logout ADR, sign-out
checklist, logout sequence/session documentation, and IdP transition inventory/diagram. The code
change rejects sequential context substitution while preserving the exact retry and existing
redirect continuation. It added no class, table, migration, route, callback, or session-store
configuration.

The original APP and ORG regression tests were Red before the guard: two failures expected 403 but
received 200. After the guard they passed, including unchanged pending session state and no
authority mutation. The CSRF failure test later exposed test-order leakage from toggling the base
controller's setting; it now changes and restores the unavailable controller's own setting inside
`ensure`, with no production test-aware branch. The test still asserts 422 before the unavailable
response.

| Acceptance                                           | Evidence                                                                                                                     |
| ---------------------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------- |
| Inventory and boundary review                        | UF31, sections A–B; this record, section A                                                                                   |
| APP/ORG sequential-mismatch Red → Green              | UF31, sections B–D; exact current focused run below                                                                          |
| Concurrent first-request behavior                    | UF31, sections B and D: two distinct PostgreSQL backend connections reproduced the race; temporary rows/file were cleaned up |
| Unavailable ceremony/Social CSRF and mode boundaries | X4H2, sections A–D; current focused run below                                                                                |
| Durable contract and transition documentation        | UF31, sections C and F                                                                                                       |

## D. Verification

- Current focused command:
  `env -u POSTGRESQL_TEST_PREPARE_DATABASES RUBY_DEBUG_ENABLE=0 RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/integration/oidc_current_device_logout_test.rb test/integration/op_existing_session_logout_test.rb test/integration/oidc_logout_realm_acceptance_test.rb test/integration/oidc_logout_enqueue_failure_test.rb test/services/oidc/end_session_request_test.rb test/services/oidc/logout_request_test.rb test/controllers/auth/app/sign_up_csrf_failure_test.rb test/integration/social_ceremony_entry_contract_test.rb test/integration/social_ceremony_start_gate_test.rb test/unit/security/authentication_mode_inventory_test.rb`
  — **112 runs, 1,042 assertions, 0 failures, 0 errors, 0 skips**.
- Current changed-file style check:
  `bin/rubocop app/controllers/concerns/sign_oidc_logout.rb test/controllers/auth/app/sign_up_csrf_failure_test.rb test/integration/oidc_current_device_logout_test.rb`
  — passed, 3 files, no offenses.
- `git diff --check` — passed.
- The latest full Rails run for this worktree is recorded in
  `evidence/2026-11-13-access-ps256-migration-6D2A.md`: **5,649 runs, 36,594 assertions, 99
  failures, 128 errors, 0 skips**. It ran after the flow implementation; the later Stage 1–3 handoff
  change was ADR-only. The full suite is not green, and the dirty-tree aggregate cannot be
  attributed solely to this work order. The prior failure inventory includes removed-model/route
  expectations and stale contracts; a clean-HEAD comparison was not available.
- `bin/rails zeitwerk:check` passed in UF31 and the PS256 migration evidence.
  `bin/rails test:system` passed there with 2 runs and 6 assertions, but those are public-surface
  smoke tests, not a logout-specific browser test. No logout-specific browser automation or
  numerical coverage for changed lines was measured.
- Static aggregate results are in `evidence/2026-11-13-ci-static-checks-9J2M.md`. The full
  repository RuboCop, JavaScript checks, and DatabaseConsistency remain non-green for recorded
  worktree findings. No finding was suppressed or fixed outside the ordered work scope.

## E. Residual risks and boundaries

- The simultaneous initial-request race remains until the accepted per-tab handle's persistent shape
  and transition contract are authorized and implemented.
- Access sign-in, sign-up, identity/credential ceremonies, recovery, social identity and authority
  freshness remain unavailable pending Governance contracts and implementation.
- Full Rails/static gates are not all green; the relevant current results and attribution limits are
  recorded above and in the linked evidence. No coverage percentage is claimed for the changed flow.
- The test database preparation output includes the existing `test_queue_db` catalog entry. No Solid
  Queue code, schema, migration, operational setting or source configuration was changed.
- `config/credentials/`, `config/database.yml` and `config/ci.rb` had no changed paths at final
  capture. No runtime changes were made during this final verification pass.
