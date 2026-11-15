# Full Rails test suite triage

- Repository: `umaxica-apps-cosmos-access`
- Branch: `feature`
- `git rev-parse HEAD`: `727cdb560d1a55d32b14ed484d34abeda6742a61`
- The worktree was already uncommitted and contained prior authorized PS256, handoff, and
  fail-closed-flow changes. Those changes affected the test results. No commit or push was made.
- No secret or environment value was recorded.
- This is the initial classification snapshot. Its post-triage count (37,488 assertions) was from an
  intermediate run and is superseded by `2026-11-14-full-test-suite-correction-H6J2.md`, which
  records the final current run: 5,574 runs, 36,876 assertions, 1 failure, 0 errors, 0 skips.

## Baseline and final run

The task description cited a prior run with 98 failures and 99 errors. The first full run available
in this checkout was different:
`env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test bin/rails test` reported 5,696 runs, 37,030
assertions, 91 failures, 106 errors, and 0 skips.

After triage and repairs, the same command reported 5,574 runs, 37,488 assertions, 1 failure, 0
errors, and 0 skips. The run count fell by 122 because obsolete tests were removed with the retired
behavior and duplicate coverage was replaced by current-contract tests.

The initial 197 unique failing cases were assigned one primary disposition:

| Disposition                  |   Cases | Basis                                                                                                                                                                                                                                            |
| ---------------------------- | ------: | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Delete                       |     103 | 98 cases were in test files whose feature or owner had been removed; 5 individual cases covered the retired Preference API, the Entra callback limiter, sign-in-resend serialization, or removed cross-surface quota/social-link entry behavior. |
| Update                       |      86 | Assertions, fixtures, route inventories, invariants, and test subjects were brought in line with the accepted PS256, fail-closed, OP-owned, and current route contracts.                                                                         |
| Code fix                     |       7 | Four retained-surface rate-limit cases exposed missing `Retry-After`; two object-placement checks exposed an unused dispatcher in the wrong layer; one token logging check exposed missing Active Record filtering for refresh-token digests.    |
| Blocked by out-of-scope work |       1 | The OpenAPI route-coverage test reports `POST /api/v0/revocation_commands` as routed but undocumented. Removing the direct HTTP route is handoff Stage 4, which this task excludes; documenting it would conflict with accepted ADR decision 18. |
| **Total**                    | **197** | 91 failures and 106 errors in the first local full run.                                                                                                                                                                                          |

## Red, Green, and repairs

- Red: the first full run above failed. After the obsolete tests were removed and current route
  contracts were updated, focused tests exposed four remaining failures in token logging, redirect
  event inventory, and rescue inventory.
- Green: the focused token/redirect/rescue set passed with 10 runs, 96 assertions, 0 failures, 0
  errors, and 0 skips. `ClientToken` and `OperatorToken` now filter `refresh_token_digest` in Active
  Record logs. The redirect test now checks the current `redirect_target.rejected` event. The prior
  no-secret assertion remains. A temporary assertion that SQL must always appear in the test's
  in-memory logger was removed after confirming the test configuration intentionally emits SQL only
  at debug level; the permanent model-filter assertions remain, and a separate real debug-level
  SQL-log probe confirmed that a query was logged without the synthetic digest value.
- Red: the next full run exposed an OP authority-stop naming invariant and stale architecture
  baseline entries, in addition to the out-of-scope route finding.
- Green: `OpAuthorityStopSingleWriterInvariantTest` and `ArchitectureBaselineTest` passed with 5
  runs, 649 assertions, 0 failures, 0 errors, and 0 skips. The risk-enforcement wrapper was renamed
  to `stop_principal_roots!` because it delegates root stopping to the single-writer committer.
  `bin/rails architecture:baseline` removed stale entries only; it measured 37 concern
  inclusion-hook offenses in 37 files and 802 explicit-visibility offenses in 283 files. No baseline
  entries were added.
- Final full run: 5,574 runs, 37,488 assertions, 1 failure, 0 errors, and 0 skips. The sole failure
  is the route/OpenAPI mismatch above. All independent in-scope repairs are complete.

## Remaining item

Resolve the `POST /api/v0/revocation_commands` route only within the handoff Stage 4 scope and its
approved front-channel contract. Until then the complete suite is not green. The test was retained;
its assertion was not removed or weakened. No pre-existing security assertion was removed or
weakened; removed test cases were limited to retired behavior described in the table above.
