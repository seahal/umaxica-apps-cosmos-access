# Public/protected method coverage continuation

## Scope and revision

- Revision: `727cdb560d1a55d32b14ed484d34abeda6742a61`.
- The worktree was dirty before and during verification (255 changed paths at capture); the results
  describe this exact worktree, not `HEAD` alone.
- Added database-backed replay-store behavior coverage for step-up, telephone, and social ceremony
  transactions. Corrected the realm encryption-key provider tests to restore environment values
  inline and avoid private test helper methods. The OneTimeReveal tests from the preceding batch
  were included in the full run.

## Red / Green and checks

- Initial focused run: 10 runs, 18 assertions, 3 failures. Each failure was an identity assertion
  against a fresh Active Record instance reloaded from PostgreSQL.
- After changing those assertions to record equality, focused verification passed: 10 runs, 21
  assertions, 0 failures/errors/skips.
- `bin/rubocop` on the four affected test files passed. `git diff --check` passed.
- Full command:
  `env -u POSTGRESQL_TEST_PREPARE_DATABASES RUBY_DEBUG_ENABLE=0 COVERAGE=true RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test`.
  Result: 5,638 runs, 36,518 assertions, 99 failures, 128 errors, 0 skips. The previous full run
  recorded 5,631 runs / 36,501 assertions with the same 99 failures and 128 errors; all new focused
  tests passed, but individual existing failure attribution was not re-audited here.
- SimpleCov reported lines 22,459/25,562 (87.86%), branches 3,075/4,951 (62.10%), and all-method
  3,519/4,231 (83.17%). It excluded 16 subprocess results older than its configured 3,600-second
  merge timeout and stopped normal processing after the suite's existing errors.
- The visibility classifier reported public/protected methods 1,630/1,890 (86.2434%): public
  instance 1,133/1,319, public singleton 488/561, and protected instance 9/10. It excluded 2,336
  private methods and 5 explicitly identified test-only records; 0 records were unclassified.

## Remaining acceptance

- `specs/public-source-coverage-completion/spec.md` AC-2 remains open; the 99% target is not met.
- No commit or push was made. No CI files were changed.
