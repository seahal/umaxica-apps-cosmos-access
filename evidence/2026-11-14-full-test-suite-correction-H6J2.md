# Full Test Suite Final Correction

## Scope and revision

- Repository: Access.
- `git rev-parse HEAD`: `727cdb560d1a55d32b14ed484d34abeda6742a61`.
- The worktree remained extensively uncommitted and affected results. No commit or push was made.
- This record supersedes the earlier final counts in `2026-11-14-full-test-suite-final-R8M3.md` and
  this file's first revision after making one flaky time-boundary assertion deterministic and
  removing inline RuboCop suppressions from the in-progress changes.

## Final test result

- Command: `env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test bin/rails test`.
- Result: **5,574 runs, 36,876 assertions, 1 failure, 0 errors, 0 skips**.
- Remaining failure:
  `OpenapiRouteCoverageTest#test_no_Auth_or_Visa_route_is_missing_from_its_surface_description`
  reports routed `POST /api/v0/revocation_commands` lacks an APP surface description.
- Disposition: this endpoint implements the superseded server-push design in ADR decision 18. Its
  removal and caller cleanup belong to Jump handoff Stage 4, explicitly out of scope. Adding a
  description would preserve the superseded contract; deleting or exempting the test would weaken
  route coverage. The route and test remain unchanged for that owner work.

## Corrected timing test

- The preceding final run had 2 failures: the route coverage failure and
  `TokenStatusManagementTest#test_revoke!_sets_expired_at_and_status_to_revoked`. The second
  assertion compared a writer database timestamp with frozen application time at a one-second
  tolerance; the measured difference crossed that boundary by 0.00135 seconds.
- The revoke API already accepts an explicit decision time. The test now supplies that time and
  asserts the persisted expiry second equals it. The adjacent test continues to check the shared
  writer-database time for both status and timestamp.
- Red evidence: the test failed in the full run when it depended on two independently advancing
  clocks. A direct isolated rerun passed once, confirming the boundary was timing-sensitive rather
  than a stable failure.
- Green evidence:
  `env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test bin/rails test test/models/concerns/token_status_management_test.rb`
  passed **22 runs, 107 assertions, 0 failures, 0 errors, 0 skips**; the subsequent full run has
  only the out-of-scope route failure.

## No-suppression refactor

- Removed 17 inline `rubocop:disable` directives from the in-progress Ruby changes. Ceremony surface
  declarations and OIDC authorization surface declarations now expose immutable readers; Sign Entry
  classification uses immutable declaration readers and an inherited action-override closure. The
  ceremony macro and Sign Entry declaration API are private/fail-fast where required.
- Red: focused tests first failed when checking that a declared ceremony surface is immutable, that
  the Sign Entry writer is absent, and that the declaration macro is not publicly callable.
- Green:
  `env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test bin/rails test test/models/concerns/ceremony_transactionable_test.rb test/unit/security/sign_entry_classification_guard_test.rb test/controllers/concerns/auth_ceremony_sid_cookie_test.rb`
  passed **32 runs, 401 assertions, 0 failures, 0 errors, 0 skips**.
- The full RuboCop run after this refactor inspected **1,996 files with 0 offenses**. The current
  diff adds no `rubocop:disable` directives.

## Failure classification

The 197 unique initial failures recorded in `2026-11-14-full-test-suite-triage-F3Q8.md` remain
classified as follows:

| Disposition                                         |   Cases |
| --------------------------------------------------- | ------: |
| Delete because the tested subject was removed       |     103 |
| Update for an accepted contract change              |      86 |
| Fix code because the retained test exposed a defect |       7 |
| Blocked by excluded Stage 4 contract work           |       1 |
| **Total**                                           | **197** |

No assertion was weakened to make the current suite pass. The full suite is not green while the one
Stage 4 route-contract failure remains. The final full-suite run was performed after the
no-suppression refactor; no test was deleted or weakened to hide the remaining failure.
