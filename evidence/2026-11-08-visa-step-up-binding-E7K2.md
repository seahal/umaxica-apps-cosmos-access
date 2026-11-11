# Access Route Separation Verification

- Date: 2026-11-08.
- HEAD: `281a9e5c539bc0b89b4d37ff5bd6f102976ad4c4`.
- The worktree has uncommitted changes, including this task's changes and prior work. Results below
  describe the dirty worktree. No commit was created.

## Security references and verification

- Removed obsolete forbidden-pattern allowlist entries for deleted OAuth controllers from
  `test/security/invariants/forbidden_patterns_invariant_test.rb`. These entries named files that no
  longer exist and therefore could not match active production code.
- Retained negative route checks for retired RP hosts in `withdrawal_gate_invariant_test.rb` and
  `read_only_route_write_invariant_test.rb`. The host registrations remain configured, and these
  tests verify the retired paths do not route or write. Also retained shared `AuthenticationBase`
  references and RP client identifiers because they are active OP/security contracts.
- `bin/rails test test/security`: 147 runs, 821 assertions, 0 failures, 0 errors, 0 skips.
- `bin/rails test test/controllers/concerns/default_web_rate_limit_test.rb`: 2 runs, 311 assertions,
  0 failures, 0 errors, 0 skips.
- `bin/rubocop`: 4,759 files inspected, no offenses.
- `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`: 0 errors, 0 security warnings.
- The Visa step-up binding group previously passed: 45 runs, 564 assertions, 0 failures, 0 errors, 0
  skips. `test/controllers/visa/app/ceremony_binding_confirmations_controller_test.rb` verifies
  matching-user OP session success, foreign-user refusal, expiry, redeemed replay, and authorization
  versus step-up parent purpose.

## Full Rails suite and attribution

- One full run was executed with `bin/rails test` and completed with exit status 1: 16,049 runs,
  112,313 assertions, 652 failures, 1,020 errors, 0 skips. The captured output is at
  `/tmp/access-full-rails-test-20261108-run11.out`; it is intentionally not copied into this record.
- The full run preceded removal of stale test-only allowlist entries and a formatting-only edit to
  one test. The security suite was rerun after its allowlist edit, and the rate-limit test was run
  after formatting. The full suite was not repeated, consistent with the requested single run.
- Clearly change-related examples are tests that still exercise deleted RP surfaces/routes,
  including `DefaultNoStorePublishingContentTest` (36 failures),
  `BaseDashboardAuthenticationGuidanceTest` (17 failures/errors), `BaseSelectorSingleWriteHttpTest`
  (2 errors), and `TechRouteContractTest` (2 failures). These test expectations refer to deleted
  endpoints/controllers and should not be counted as regressions in retained Auth/Visa behavior
  without updating their scope.
- The recorded pre-change aggregate was 17,164 runs, 146,002 assertions, 302 failures, 192 errors, 0
  skips. Its individual test names and failure details were not saved. The current suite also has a
  different set of tests after removed-surface test cleanup. Therefore the aggregate delta (+350
  failures, +828 errors, -1,115 runs, -33,689 assertions) cannot identify which individual failures
  existed before. Failures in retained/shared Auth, Visa, OIDC, and infrastructure tests are
  unclassified between pre-existing and change-caused; they need a comparable named baseline to
  assign conclusively.
- Earlier full-suite startup errors from tests loading deleted `Base`/RP constants were corrected
  before the completed run. They are not included in the completed run's totals.

## Scope and limits

- The Rails test database was used. No development database or volume was reset or deleted. No
  container operation, credentials or key change, external service change, or commit was performed.
- No secrets, tokens, cookies, or credential values are recorded here.
- Retired-host behavior at a live deployment edge and Cloudflare connector state remain unverified.
