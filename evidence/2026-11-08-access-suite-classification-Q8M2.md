# Access security and full-suite result

## Snapshot

- HEAD: `281a9e5c539bc0b89b4d37ff5bd6f102976ad4c4`
- The worktree contained extensive uncommitted and untracked Access separation changes; the results
  below apply to that worktree. No commit was created.
- The test database catalog reported only `test_*` databases for the Rails test run. No development
  database or volume was reset.

## Checks

- `PARALLEL_WORKERS=1 bin/rails test test/security`: **144 runs, 821 assertions, 0 failures, 0
  errors, 0 skips**.
- One full run, `PARALLEL_WORKERS=1 bin/rails test`: **15,236 runs, 112,738 assertions, 379
  failures, 437 errors, 0 skips**. The raw output was kept outside the repository and is not
  reproduced here.
- After the full run, a focused run of `test/security`, the two layout contract tests and
  `ClientSecretAuditDeliveryJobTest` passed: **166 runs, 1,503 assertions, 0 failures, 0 errors, 0
  skips**. This includes the final layout and test changes described below; the full suite was not
  repeated.
- RuboCop on the three changed Ruby test files: **3 files inspected, no offenses**.
- `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`: **0 errors, 0 security
  warnings**.
- `git diff --check`: passed after the final layout cleanup.

## Failure classification

The immediately preceding post-separation full run recorded 15,795 runs, 110,895 assertions, 496
failures and 925 errors, with named failure identifiers saved. Comparing identifiers, **813 of the
816 unique identifiers in this run also failed in that immediately preceding run**. These are
unchanged from the test-cleanup baseline, so they are classified as pre-existing relative to this
cleanup. The current run has 608 unique identifiers from the preceding run that no longer appear,
consistent with tests removed or updated during the surface cleanup.

Three unique identifiers were new relative to that preceding run:

- `LayoutTitleContractTest#test_layout_roots_remain_constrained_to_Auth_and_Visa` found three stale
  Jump layout files. They were removed, together with the retired surface entries in
  `config/frontend_stacks.yml`.
- `StylesheetTagsTest#test_Auth_layouts_include_shared_chrome_and_semantic_landmarks` expected
  navigation in Auth layouts. The test now asserts the procedure-only layout has no navigation,
  consistent with the no-out-of-procedure-navigation contract.
- `ClientSecretAuditDeliveryJobTest#test_a_conflicting_Secret_audit_does_not_starve_later_pages`
  appeared only in the full run and passed in the focused run. Its full-suite-only failure was not
  reproduced and remains order-dependent or otherwise unexplained.

The earlier pre-separation aggregate was 17,164 runs, 146,002 assertions, 302 failures and 192
errors, but its individual failure details were not saved. Therefore, the 813 unchanged identifiers
can only be called pre-existing relative to the immediately preceding post-separation run; they
cannot be proven individually pre-existing relative to the original tree. The current full suite
still has substantial failures and errors; this evidence does not claim that the suite passes.

## Base host references in `test/security/`

The remaining `PUBLIC_BASE_SERVICE_URL` and `PUBLIC_BASE_STAFF_URL` references are negative
route-recognition tests for retired identity, withdrawal, secret, selector and Governance-system
paths. They assert those paths are unroutable on the retired hosts. They are intentionally retained
as cross-host denial checks. No deleted Base route helper is called from `test/security/`.
