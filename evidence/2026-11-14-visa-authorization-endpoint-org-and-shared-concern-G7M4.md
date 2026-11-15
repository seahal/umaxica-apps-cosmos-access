# Visa App and Org Authorization Endpoint Reopening

## Scope and source snapshot

- Work orders: `plans/2026-11-14-visa-app-authorization-endpoint-reopening-work-order.md` and its
  extension `plans/2026-11-14-visa-authorization-endpoint-org-and-shared-concern-work-order.md`.
- Recorded HEAD before edits: `727cdb560d1a55d32b14ed484d34abeda6742a61`
  (`Checkpoint Cosmos split work in progress (2026-11-13)`).
- `727cdb560~1` resolves to `f84c87b060876a25994e30e9274420d9067f1367`.
- The worktree was already dirty, including Visa logout/revocation controllers, tests, diagrams,
  checklists and multiple untracked evidence records. Those changes were present before this work
  and are preserved; they can affect broad check results.
- The pre-edit inventory below was recorded before implementation. Final results follow it.

## Pre-edit inventory

| Path / component                                                                                                 | At `727cdb560~1` | In current worktree before edits | Needed for start-only endpoint                                                                                                                                    |
| ---------------------------------------------------------------------------------------------------------------- | ---------------- | -------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `app/controllers/visa/app/oauth/authorizations_controller.rb`                                                    | Present          | Absent                           | Restore as thin App controller using shared start concern.                                                                                                        |
| `app/controllers/visa/app/authorization_base_controller.rb`                                                      | Present          | Absent                           | Do not restore wholesale; it contains result, session, step-up and sign-up continuations outside this order.                                                      |
| `app/controllers/visa/org/oauth/authorizations_controller.rb`                                                    | Present          | Absent                           | Restore as thin Org controller using the same shared start concern.                                                                                               |
| `app/controllers/visa/org/authorization_base_controller.rb`                                                      | Present          | Absent                           | Do not restore wholesale; non-start methods are outside this order.                                                                                               |
| `app/controllers/concerns/oauth_authorize_rate_limit.rb`                                                         | Present          | Absent                           | Restore/adapt request-window limit methods; register callbacks explicitly in each controller, without inclusion hooks.                                            |
| `app/controllers/concerns/oauth_authorize_request_size_limit.rb`                                                 | Present          | Absent                           | Restore/adapt request-size check; explicitly register it in each controller.                                                                                      |
| `app/controllers/concerns/oidc_authorization_request_errors.rb`                                                  | Present          | Absent                           | Restore shared duplicate-field and trusted-target error responses.                                                                                                |
| `app/controllers/concerns/authorization_audit.rb`                                                                | Present          | Absent                           | History shows authorization-failure handling, not an authorization-start writer. It is not part of the removed start path and will not be restored for this task. |
| `app/controllers/concerns/oidc_authorization_result_post.rb`                                                     | Present          | Absent                           | Explicitly out of scope; do not restore result/continuation POST handling.                                                                                        |
| `app/controllers/concerns/oidc_authorization_continuation.rb`                                                    | Present          | Absent                           | Explicitly out of scope; do not restore continuation/code completion behavior.                                                                                    |
| `config/routes/visa.rb`                                                                                          | Present          | Present                          | Change the App and Org authorization resource targets; leave other routes intact.                                                                                 |
| `OidcAuthorizeRequestResolver`                                                                                   | Present          | Present                          | Validate realm-bound client, exact redirect, required OIDC fields, PKCE, prompt and duplicates.                                                                   |
| `OidcAuthorizationTransactionCoordinator`                                                                        | Present          | Present                          | Persist one authorization transaction and Base/Auth handoff.                                                                                                      |
| `ClientOidcAuthorizationTransaction`, `OperatorOidcAuthorizationTransaction`, `OidcAuthorizationTransactionable` | Present          | Present                          | Store the realm-specific validated authorization transaction.                                                                                                     |
| `OidcPkce`, `OidcClientRegistry`                                                                                 | Present          | Present                          | Existing PKCE and registered-client/redirect contracts remain authoritative.                                                                                      |
| `BaseAuthAdmissionCoordinator`                                                                                   | Present          | Present                          | Issue the browser-bound admission handoff.                                                                                                                        |
| `JumpRtReturnVerification`                                                                                       | Present          | Present                          | Verify and remove incoming `rt` before OIDC parsing; preserve it outside OIDC parameters.                                                                         |
| `OpBrowserSessionRequest`                                                                                        | Absent           | Present                          | Current Authority controller supplies session lookup; no silent SSO/code issuance will be restored.                                                               |
| `BaseAdmissionBrowserBinding`                                                                                    | Present          | Present                          | Create/reuse the browser nonce required for handoff issuance.                                                                                                     |
| `test/integration/visa_authorization_start_boundary_test.rb`                                                     | Present          | Absent                           | Restore/adapt boundary, refusal and transaction-allocation tests for both realms.                                                                                 |
| `test/integration/oidc_authorization_parameter_multiplicity_test.rb`                                             | Present          | Absent                           | Restore/adapt duplicate-parameter tests for both realms.                                                                                                          |
| `test/integration/acceptance_wu13_authorize_unrelated_params_test.rb`                                            | Present          | Absent                           | Restore continuation-parameter refusal coverage for both realms.                                                                                                  |
| `test/services/oidc/authorize_service_test.rb`                                                                   | Present          | Absent                           | Restore existing code-issuer regression coverage if it remains compatible with current collaborators.                                                             |
| `test/services/oidc_authorization_transaction_service_test.rb`                                                   | Present          | Absent                           | Restore current transaction/admission-coordinator contract coverage.                                                                                              |
| `test/controllers/visa/ceremony_unavailable_test.rb`                                                             | Absent           | Present                          | Update to expect both Visa authorization starts to reopen while Auth ceremonies stay unavailable.                                                                 |

## Contract observations before edits

- The request-profile ADR requires unknown parameter names to remain ignored and rejects repeated
  recognized parameters. This takes precedence over interpreting arbitrary unknown names as OIDC
  fields; known continuation fields remain explicitly refused.
- The resolver accepts `prompt=create` for App and excludes it for Org. The restored path will not
  restore the old sign-up branch; App `prompt=create` remains recorded in the OIDC transaction and
  uses the allowed sign-in handoff. Org behavior remains the resolver's direct prompt refusal.
- The CommonRedirect implementation logs only digests for outgoing redirect target/token metadata.
  The restored rate-limit and authorization-start paths must not log URL values or OIDC secrets.
- No code or configuration had been edited for this work when this inventory was recorded.

## Implementation and final verification — 2026-11-14

### Result and boundary

- The work ran only in this Access checkout. `git rev-parse HEAD` remains
  `727cdb560d1a55d32b14ed484d34abeda6742a61`; no commit or push was made.
- The worktree was already dirty before implementation. Existing edits in this tree affected
  full-suite and OpenAPI verification results; unrelated changes were preserved.
- Both Visa App and Visa Org now route `GET` and `POST /oauth/authorize` to their thin realm
  controller. Each controller supplies realm hooks; shared request handling is in
  `OidcAuthorizationStart`, `OauthAuthorizeRateLimit`, `OauthAuthorizeRequestSizeLimit`, and
  `OidcAuthorizationRequestErrors`. Missing realm hooks fail with `NotImplementedError`; shared
  concerns do not branch on realm.
- Valid requests are resolved against the realm's registered client and exact redirect URI, then a
  pending OIDC transaction and Base/Auth admission binding are created and the browser is sent with
  `303` through Jump to that realm's Auth `/sign/in/sentry`.
- A present OP session is not silently used to complete authentication or issue a code. The session
  root may be carried as the admission binding; the existing device session is not revoked.
  `prompt=none` returns `login_required` without creating a transaction. Step-up and Org
  `prompt=create` remain refused by the existing resolver. App `prompt=create` is recorded but
  follows the sign-in sentry; the removed sign-up branch was not restored.
- `HEAD` and known continuation/result parameters are rejected. Repeated recognized OIDC parameters
  are rejected. Arbitrary unknown parameter names remain ignored as required by
  `adr/oidc-authorization-request-profile.md`; this accepted ADR contract takes precedence over the
  older work-order wording that unknown names should be refused.
- Request size and rate checks run before resolution. Responses set `Cache-Control: no-store` and
  `Referrer-Policy: no-referrer`; route normalization is skipped so protocol parameters are not
  changed before validation. No URL, OIDC state, nonce, verifier, token, or code is written to
  application logs.
- History's App/Org authorization-start logic was consolidated into the four concerns above. The old
  `authorization_base_controller.rb` copies, result/code completion, continuation, silent SSO,
  sign-up dispatch, step-up dispatch, O9 sensitive-admission dispatch, and result POST were not
  restored. No authorization-start audit writer was restored because the historical start path did
  not have one and the current scope does not authorize introducing a new audit contract.
- Current Access no longer has the historical `Client`/`Operator` principal models. Realm resource
  hooks therefore use the current session's `ClientToken`/`OperatorToken` root and their
  corresponding resource types; no removed model was reintroduced.
- No schema or migration changed. No environment variable or credential was added or edited.
  `git status --short -- config/credentials` was empty. `config/routes/visa.rb` was the only
  `config/` path changed.

### Files changed for this work

- Shared concerns: `app/controllers/concerns/oidc_authorization_start.rb`,
  `oauth_authorize_rate_limit.rb`, `oauth_authorize_request_size_limit.rb`, and
  `oidc_authorization_request_errors.rb`.
- Thin App and Org controllers: `app/controllers/visa/app/oauth/authorizations_controller.rb` and
  `app/controllers/visa/org/oauth/authorizations_controller.rb`.
- Routing: `config/routes/visa.rb`.
- Tests: the three restored integration tests
  `test/integration/visa_authorization_start_boundary_test.rb`,
  `test/integration/oidc_authorization_parameter_multiplicity_test.rb`, and
  `test/integration/acceptance_wu13_authorize_unrelated_params_test.rb`; updated
  `test/services/oidc/authorize_service_test.rb`,
  `test/services/oidc_authorization_transaction_service_test.rb`,
  `test/controllers/visa/ceremony_unavailable_test.rb`,
  `test/integration/oidc_current_device_logout_test.rb`, and
  `test/integration/routes/app_rails_edge_ownership_contract_test.rb`.
- Current docs: `README.md`, `plans/2026-11-12-handoff.md`, `docs/checklists/authentication.md`,
  `docs/mermaid/idp-client-oidc-authorization.mmd`,
  `docs/mermaid/idp-operator-oidc-authorization.mmd`, and
  `docs/mermaid/idp-state-machine-transition-inventory.md`.
- `docs/mermaid/idp-state-machine-transition-inventory.md` also contains a separate OIDC
  logout-transition row edit in the pre-existing dirty worktree. That unrelated edit was left intact
  and is not attributed to this authorization-start change.
- `app/values/oidc_discovery_document.rb` was not changed. Discovery still advertises
  authorization-code response/grant support while Auth ceremonies and the Visa result/code
  completion path remain unavailable. PAR and request-object support are not advertised. This
  end-to-end capability mismatch is recorded for follow-up as required by the work order.

### TDD and test results

- Before the implementation, the restored/adapted endpoint test set ran Red: 106 runs, 89
  assertions, 64 failures, 40 errors, 0 skips. The failures showed the missing Visa
  controllers/routes and stale collaborators; the errors showed references to removed controller
  actions/models.
- After implementation and final boundary updates, focused tests passed: 145 runs, 1,647 assertions,
  0 failures, 0 errors, 0 skips. This includes both realms, valid Jump handoffs, exact redirect
  validation, cross-realm refusal, missing/malformed protocol fields, recognized duplicates,
  `prompt=none`, `prompt=create`, request size/rate boundaries, continuation refusal, Auth 503
  behavior, and preservation of existing device sessions.
- `test/integration/oidc_current_device_logout_test.rb` previously expected the now-reopened
  authorization endpoint to return 503. It now verifies a valid start returns a Jump handoff and
  does not revoke or stop the existing device. `AppRailsEdgeOwnershipContractTest` now asserts App
  and Org authorization routes belong to their new controllers.
- Full Rails suite, with the stale `POSTGRESQL_TEST_PREPARE_DATABASES` list unset (its value was not
  printed): 5,658 runs, 37,738 assertions, 1 failure, 0 errors, 0 skips. The remaining failure is
  `OpenapiRouteCoverageTest#test_no_Auth_or_Visa_route_is_missing_from_its_surface_description`: the
  existing `POST /api/v0/revocation_commands` route is absent from `openapi/app.yml`. That route is
  present in the committed `config/routes/visa.rb` and was not changed by this work; this unrelated
  API documentation issue remains open.
- Coverage was not measured separately.

### Checks

- `env -u POSTGRESQL_TEST_PREPARE_DATABASES bin/rails zeitwerk:check`: passed (`All is good!`).
- `env -u POSTGRESQL_TEST_PREPARE_DATABASES bin/rails routes`: passed; output confirms App and Org
  GET/POST authorization routes target `visa/app/oauth/authorizations` and
  `visa/org/oauth/authorizations`.
- Full `bin/rubocop`: passed, 2,007 files inspected, no offenses. After updating the two
  route/session regression tests, targeted RuboCop passed, 2 files inspected, no offenses.
- `bundle exec erb_lint --lint-all`: passed, 541 files, no errors. The parser/current Ruby-version
  notice was non-fatal.
- `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`: passed, 0 security warnings.
- `bun run check`: format check, Oxlint, typecheck coverage guard, TypeScript build, Knip, and
  Redocly lint passed. `openapi:verify` failed because it runs `redocly bundle` and then compares
  generated bundles to Git HEAD. The existing dirty OpenAPI source removes the retired preference
  endpoints while the committed bundles still contain them; the bundle command regenerated
  `openapi/bundled/openapi.app.yml` and `openapi/bundled/openapi.org.yml`, producing the expected
  uncommitted diff. Those generated file changes are preserved; this task did not edit OpenAPI
  sources or Discovery.
- `git diff --check`: passed.

### Browser expectation and remaining items

- From `https://www.umaxica.app/sign`, a valid Base App request should receive `303` through Jump
  and the browser should end at `auth.umaxica.app/sign/in/sentry`, which still answers `503` because
  Auth sign-in remains unavailable. The corresponding Org route hands off to Auth Org in the same
  way. No live browser check was performed.
- Sign-in cannot complete and no authorization code is issued until the separate Auth
  ceremony/result work reopens. This was an accepted boundary, not hidden by a fallback.
- Follow-up items: document the existing Visa revocation-command endpoint in OpenAPI (or record an
  accepted reason for its omission), reconcile generated OpenAPI bundles with the already-modified
  sources, and align Discovery's advertised code-flow support with the still-unavailable Auth/result
  completion path. No schema, credential, ADR, deployment, CI, or external-system change was needed
  for this task.
