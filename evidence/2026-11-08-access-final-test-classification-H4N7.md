# Access route separation test classification

## Snapshot

- HEAD: `281a9e5c539bc0b89b4d37ff5bd6f102976ad4c4`.
- The worktree contained uncommitted and untracked changes. No commit was created.
- Rails reported the test database catalog with `test_*` databases only. No development database or
  volume was reset.

## Checks

- `PARALLEL_WORKERS=1 bin/rails test test/security`: **144 runs, 821 assertions, 0 failures, 0
  errors, 0 skips**.
- One full run, `PARALLEL_WORKERS=1 bin/rails test`: **15,236 runs, 113,157 assertions, 355
  failures, 431 errors, 0 skips**.
- After that full run, the four email/SMS checkpoint tests were changed to exercise the committed
  delivery boundary and clean up only their test-owned rows.
  `PARALLEL_WORKERS=1 bin/rails test test/controllers/auth/sign_up_checkpoint_cancellation_test.rb`:
  **4 runs, 15 assertions, 0 failures, 0 errors, 0 skips**. The full suite was not rerun after this
  focused correction.
- `bin/rubocop test/controllers/auth/sign_up_checkpoint_cancellation_test.rb`: **1 file inspected,
  no offenses**.
- `git diff --check`: passed.
- No calls to deleted Base/Core route helpers were found in the remaining Auth, Visa, or mailer Ruby
  code.

## Base references retained in `test/security/`

The remaining Base host references are negative route checks for retired identity, withdrawal,
secret, selector, and Governance paths, plus tests of explicit OP/RP data boundaries. These checks
remain useful after route removal and do not call deleted route helpers. Host registration is
preserved separately from route ownership.

## Failure classification

The immediately preceding full run recorded 15,236 runs, 112,738 assertions, 379 failures, and 437
errors. This run's 786 unique failure/error test identifiers all appeared in that preceding run: **0
new identifiers**. Thirty identifiers from the preceding run no longer appeared. The suite therefore
improved by 24 failures and 6 errors, with 419 more assertions executed.

The full run above preceded a focused correction to `AuthSignUpCheckpointCancellationTest`. All four
of its failures returned HTTP 503 because the test's enclosing transaction prevented the production
OTP delivery issuer from observing committed Source and Ticket records. Those four tests now opt out
of the enclosing transaction and remove their newly created test records in teardown; the focused
file passes. No post-correction full-suite count is claimed.

The original pre-separation run was reported as 17,164 runs, 146,002 assertions, 302 failures, and
192 errors, but its individual failure details were not saved. The failures observed in the full run
above were all pre-existing relative to the immediately preceding full run. Without the original
identifiers, individual failures cannot be classified against the original tree. In particular, this
result does not establish that every current failure predates the full route-separation change, and
the full suite does not pass.

The raw full-run output remains outside the repository and is not reproduced here.
