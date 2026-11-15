# Public source coverage completion plan

## Execution order

1. Record the exact checkout, existing worktree state, Vitest and Minitest baseline, and a
   visibility-classified public/protected method inventory.
2. Close the small Vitest source gaps with behavior-level component, resolver and SSR tests. Run
   focused Vitest tests after each group, then the full coverage command.
3. Classify current Ruby public/protected gaps by production caller, route, accepted behavior and
   prior full-suite failure. Test reachable behavior through existing public callers; correct
   contract defects where evidence supports the change. Remove code only when it is proven dead or
   superseded.
4. Re-run changed Ruby tests, the full Minitest coverage suite and the public/protected method
   report. Resolve new failures and rerun the relevant gates.
5. Update this spec and append evidence with exact metrics, changed paths, test results, remaining
   failures and limits.

## Verification

- Vitest: `bun run test:coverage`.
- Rails: focused changed test files, followed by
  `env -u POSTGRESQL_TEST_PREPARE_DATABASES RUBY_DEBUG_ENABLE=0 COVERAGE=true RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test`
  when the affected Ruby batches are complete.
- Ruby style for changed Ruby files: `bin/rubocop <changed paths>`.
- TypeScript format/lint/type checks for changed frontend files: `bun run check` if changes extend
  beyond tests; coverage execution always remains required.
- Public/protected metric: classify the SimpleCov method records for `app/` and `lib/` by actual
  runtime method visibility; fail the report if any production record is unclassified.

CI files are excluded and will not be edited.
