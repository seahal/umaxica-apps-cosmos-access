# Access Security and Full Rails Test Results

- Date: 2026-11-08.
- HEAD: `281a9e5c539bc0b89b4d37ff5bd6f102976ad4c4`.
- The worktree was already uncommitted and had 1,319 changed, deleted, or untracked paths when the
  full suite ran. This evidence file adds one untracked path, for 1,320 at final status. No commit
  was created.

## Security references

- `test/unit/security/acme_rename_inventory_test.rb` no longer expects retired Base root route
  helpers to exist. It asserts those helpers are absent and keeps the `core-app-jp` OIDC client
  registration assertion, consistent with Access remaining an OP.
- Retired-host negative route checks remain in
  `test/security/invariants/withdrawal_gate_invariant_test.rb`,
  `test/security/invariants/org_withdrawal_gate_invariant_test.rb`, and
  `test/security/invariants/read_only_route_write_invariant_test.rb`. These use retained host
  registrations to prove removed paths do not route and do not expose content or writes.
- `bin/rails test test/unit/security/acme_rename_inventory_test.rb test/security`: 146 runs, 834
  assertions, 0 failures, 0 errors, 0 skips.

## Full Rails test results

- The first `bin/rails test` run completed with 15,795 runs, 110,891 assertions, 497 failures, 925
  errors, and 0 skips. Its output filter discarded case names.
- A second `bin/rails test` run was needed to capture sanitized failure/error identifiers (case
  names and test paths only; no assertion bodies or values). It completed with 15,795 runs, 110,895
  assertions, 496 failures, 925 errors, and 0 skips. This run preceded the security test expectation
  correction above; the corrected test and `test/security` passed afterward.
- Directly stale route/draw expectations identified include
  `Security::AcmeRenameInventoryTest#test_Base_route_helpers_and_OIDC_clients_are_present` (fixed as
  described above), `OpenapiContentEntriesContractTest` cases expecting retired Docs/Help/News/Info
  endpoints, and old Base/Core/Warp local-session or handoff route cases. These are change-related
  test expectations and need individual removal or conversion to route-absence assertions according
  to the retained-surface scope.
- The user-provided pre-change aggregate was 17,164 runs, 146,002 assertions, 302 failures, and 192
  errors; named failures were not retained. Because the test population has since changed and named
  baseline results are unavailable, the other current failures/errors cannot be assigned
  individually to the change or to the original baseline. Aggregate count differences do not prove
  cause. The full suite is not green.

## Static checks and limits

- `bin/rubocop`: 4,728 files inspected, no offenses. The run initially found 83 autocorrectable
  offenses in the current edited files; those formatting corrections were applied before the
  captured full-suite rerun.
- `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`: passed; 0 errors and 0 security
  warnings.
- `git diff --check`: passed.
- Rails tests used the test database. Development databases/volumes, credentials, signing-key
  handling, external services, and containers were not changed or operated. No secrets, tokens, or
  cookie values are recorded here.
