# Access security tests and full-suite classification

## Snapshot

- HEAD: `281a9e5c539bc0b89b4d37ff5bd6f102976ad4c4`.
- The worktree contained extensive uncommitted and untracked changes; no commit was created. Results
  apply to the dirty worktree at each command's execution time.
- Rails reported only `test_*` databases for the test runs. No development database or volume was
  reset.

## Checks

- `PARALLEL_WORKERS=1 bin/rails test test/security`: **144 runs, 821 assertions, 0 failures, 0
  errors, 0 skips** (rerun after the social cancellation change).
- Search of `test/security/` for deleted Base/Core/Warp route helper calls: **none found**. Retained
  Base host references are negative routing and host-boundary checks.
- `PARALLEL_WORKERS=1 bin/rails test test/integration/social_login_soc_test.rb`: **24 runs, 442
  assertions, 0 failures, 0 errors, 0 skips** (rerun after RuboCop corrections).
- Final full run, `PARALLEL_WORKERS=1 bin/rails test`: **15,093 runs, 113,349 assertions, 291
  failures, 380 errors, 0 skips**. This was the final full run after the focused fixes. An earlier
  full run exposed 15 new Social Login signup errors from removed Base switch-form assumptions; the
  tests were migrated to direct OIDC entry and the final focused Social Login run passes.
- `bin/rubocop`: **4,688 files inspected, no offenses**.
- `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`: **0 errors, 0 security
  warnings**.
- `git diff --check`: passed.

## Failure classification

The immediately preceding full run recorded **15,236 runs, 113,157 assertions, 355 failures, and 431
errors**. Comparing unique failure/error test identifiers with the final full run:

- **670 identifiers** appeared in both. They persisted from the immediately preceding worktree run.
  The original pre-separation run has only aggregate counts, so individual attribution to that tree
  is unproven.
- **116 identifiers** appeared only in the preceding run. The set includes retired-surface tests
  removed during separation and tests corrected since then; it cannot be assigned one cause from
  identifier comparison alone.
- **1 identifier** appeared only in the final run:
  `ClientSecretAuditDeliveryJobTest#test_a_conflicting_Secret_audit_does_not_starve_later_pages`.
  Its job, service, and test files are untouched by this work. A focused run reproduced the failure
  (**1 run, 1 assertion**): the expected `ArgumentError` was not raised. This is unrelated to the
  changed files, but cannot be proven pre-existing against the original tree because its individual
  failure list was not retained.

The original pre-separation result was **17,164 runs, 146,002 assertions, 302 failures, and 192
errors**, with no individual failure details. The final full suite does not pass; this record does
not claim otherwise.

## Error inventory from the final full run

The saved run at `/tmp/access-full-final-20261109.log` contains 380 errors. Classification below
uses the reported exception and its first repository frame; the split-cause category identifies
references to removed surface routes, controllers, views, or former Base RP handoffs.

| Exception                                      |   Count | Split-caused | Main pattern                                                                                                                                                                                                                                                  |
| ---------------------------------------------- | ------: | -----------: | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `NoMethodError`                                |     285 |          285 | 190 deleted route helpers, 78 attempts to read a form from the removed Base sign-in entry, 15 reads from removed Base sign-up forms, and 2 old DOM `fetch` calls.                                                                                             |
| `NameError`                                    |      52 |           52 | Removed Base/Core/Edit constants, route helpers, route/view source files, and Base test-controller context.                                                                                                                                                   |
| `ActionController` exceptions                  |      13 |           13 | 8 requests to removed-host routes and 5 tests that lack the former relying-party welcome return. The latter is an intentional explicit `BadRequest` contract after removal of the RP return; tests need OIDC context or should assert the explicit rejection. |
| `Errno::ENOENT`                                |       8 |            8 | Reads of deleted Base/Edit route, controller, and layout files.                                                                                                                                                                                               |
| `ArgumentError`                                |       9 |            0 | Invalid registration, OTP, enforcement, and test invocation arguments.                                                                                                                                                                                        |
| `AvatarOwnershipTransfers::InvalidTransfer`    |       4 |            0 | Invalid step-up binding in transfer tests.                                                                                                                                                                                                                    |
| `ActiveRecord` exceptions                      |       2 |            0 | Duplicate active grant and missing client record.                                                                                                                                                                                                             |
| `Timeout::Error`                               |       2 |            0 | Preference-write/purge concurrency tests.                                                                                                                                                                                                                     |
| Delivery unavailable exceptions                |       2 |            0 | Sign-up delivery precondition failures.                                                                                                                                                                                                                       |
| `IdentityTotpNameCommitter::DependencyFailure` |       1 |            0 | Lock timeout while committing a TOTP rename.                                                                                                                                                                                                                  |
| `RuntimeError`                                 |       1 |            0 | Auth admission test setup did not start a ceremony binding.                                                                                                                                                                                                   |
| `ActionView::Template::Error`                  |       1 |            0 | Malformed request parameter parsing in API negotiation test.                                                                                                                                                                                                  |
| **Total**                                      | **380** |      **358** | **22 errors are outside the decomposition category above.**                                                                                                                                                                                                   |

The most affected files in the saved run were `test/integration/social_login_admission_test.rb`
(22), `test/integration/social_auth_login_test.rb` (18),
`test/integration/inertia_page_contract_test.rb` (13),
`test/integration/contact_email_signup_source_audit_test.rb` (12), and
`test/integration/fqdn_availability_gate_test.rb` (11). Other notable groups were
`test/integration/omniauth_callbacks_test.rb` (10),
`test/controllers/csp_violation_reports_controller_test.rb` (10),
`test/integration/admission_curfew_test.rb` (8), and
`test/integration/sign/app/credential_removal_constraints_test.rb` (8).

After this saved full run, the Base-only Inertia page-contract test was removed because its endpoint
is not part of Access. The FQDN gate contract now exercises Visa's retained `/oauth/authorize` route
and Visa health paths; the Vite nonce contract now starts from an OIDC-admitted Auth sign-in page;
and CSP route coverage uses retained Auth/Visa hosts. The contact-email signup source-audit flow now
starts through the existing OIDC sign-up admission helper. Five `Auth::BaseTest` cases that expected
the retired RP welcome destination were replaced with an explicit missing-return rejection
assertion.

Targeted reruns passed: FQDN and Vite tests, **16 runs, 760 assertions**; CSP controller test, **11
runs, 80 assertions**; contact-email signup source audit, **12 runs, 388 assertions**.
`Auth::BaseTest` completed with **31 runs, 76 assertions, 1 failure, 0 errors**; the remaining
failure is the unrelated `JwtConfiguration.audiences` expectation at
`test/controllers/concerns/auth/base_test.rb:487`. `git diff --check` passed. The final post-cleanup
full run is recorded below.

## Post-cleanup full run

After removing the Base-only RP page, preference-control, session-revocation, withdrawal, and
credential-removal contracts, and moving retained Auth/Visa route contracts to their owners,
`PARALLEL_WORKERS=1 bin/rails test` completed with **14,920 runs, 114,047 assertions, 270 failures,
165 errors, 0 skips**. The command ran on the configured test databases only. The complete output is
in `/tmp/access-full-final-current-20261109.log`.

| Exception                                      |   Count | Decomposition cause |
| ---------------------------------------------- | ------: | ------------------: |
| `NoMethodError`                                |     120 |                 120 |
| `NameError`                                    |      23 |                  23 |
| `ActionController::RoutingError`               |       1 |                   1 |
| `ArgumentError`                                |       9 |                   0 |
| `AvatarOwnershipTransfers::InvalidTransfer`    |       4 |                   0 |
| `ActiveRecord` exceptions                      |       1 |                   0 |
| `Timeout::Error`                               |       2 |                   0 |
| `IdentityTotpNameCommitter::DependencyFailure` |       1 |                   0 |
| `RuntimeError`                                 |       1 |                   0 |
| OTP delivery unavailable exceptions            |       2 |                   0 |
| `ActionView::Template::Error`                  |       1 |                   0 |
| **Total**                                      | **165** |             **144** |

The remaining **144 split-caused errors** are removed-route/controller references and old Base RP
browser-entry assumptions. The largest locations are
`test/integration/social_login_admission_test.rb` (22), `test/integration/social_auth_login_test.rb`
(18), `test/integration/omniauth_callbacks_test.rb` (10),
`test/integration/admission_curfew_test.rb` (8),
`test/controllers/concerns/sign/email_registration_flow_test.rb` (6),
`test/integration/apple_auth_test.rb` (6), and `test/controllers/concerns/oidc/callback_test.rb`
(5). The 78 `NoMethodError: css for nil` errors in these social/Auth flows come from tests trying to
parse the retired Base `/sign` form; they still need migration to the OIDC admission path. The rest
include removed Base/Core/Edit route helpers and constants.

Other affected locations include `test/integration/enforcement_identifier_attachment_gate_test.rb`
(4), `test/concurrency/com_preference_write_purge_test.rb` (4),
`test/integration/social_auth_app_flow_contract_test.rb` (4),
`app/operations/avatar_ownership_transfers/operation.rb` (4; unrelated invalid step-up binding),
`test/unit/views/publishing_entry_presentation_test.rb` (4),
`test/integration/cross_surface_isolation_test.rb` (4), and
`test/integration/social_auth_provider_boundary_test.rb` (4).

Since the original 380-error run, **214 of the 358 classified split-caused errors are no longer
present**. The full suite still has 144 decomposition-caused errors and 270 failures; this work is
not complete. The Auth/Visa `test/security` suite passes (**144 runs, 821 assertions**).
`bin/rubocop` passes (**4,656 files, no offenses**) after correcting style findings. Retained
robots-route coverage passes (**7 runs, 59 assertions**). A separate `AuthRegionContractTest`
targeted run exposed an existing admission-redemption failure also present in the full run, so it is
not reported as passing.

Raw test output remains outside the repository and is not reproduced here. No credentials, keys,
cookies, tokens, or sensitive request values were recorded.
