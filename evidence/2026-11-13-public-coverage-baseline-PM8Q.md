# Public-source coverage baseline and Vitest completion

Revision: `727cdb560d1a55d32b14ed484d34abeda6742a61` (`git rev-parse HEAD`). The checkout was
already dirty from the authorized Access work orders and remains uncommitted: at this record it had
190 changed paths (109 modified, 68 deleted and 13 untracked). Those changes affect the measured
source and tests; the numbers below describe this exact worktree. No commit or push was made.

## Baseline

- `bun run test:coverage` before the additional behavior tests: 15 test files / 103 tests passed,
  but the command exited 1 at its existing thresholds. Source coverage was statements 121/126
  (96.03%), branches 134/144 (93.05%), functions 43/43 (100%) and lines 116/121 (95.86%). Thresholds
  were not changed.
- `env -u POSTGRESQL_TEST_PREPARE_DATABASES RUBY_DEBUG_ENABLE=0 COVERAGE=true RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test`:
  5,585 runs, 35,262 assertions, 102 failures, 145 errors and 0 skips. SimpleCov reported lines
  22,320/25,928 (86.08%), branches 3,009/5,005 (60.11%) and all-method coverage 3,336/4,353
  (76.63%). These failures are present in the current dirty checkout and are not attributed to this
  coverage change.
- `env -u POSTGRESQL_TEST_PREPARE_DATABASES RUBY_DEBUG_ENABLE=0 RAILS_ENV=test bin/rails runner -e test script/public_protected_method_coverage.rb`:
  public/protected 1,468/1,987 (73.8802%); 519 methods had no recorded call. The classifier resolved
  all production records by runtime visibility. It excluded 2,361 private records and five records
  from the test-only `Sign::WebauthnTest::TestController`, which exists only to exercise a concern's
  Rails-generated class attribute. No production method record was unclassified.

## Vitest change and verification

The source gaps had meaningful existing contracts: APP/ORG entrypoints must load only their own page
glob; an Inertia boot must omit absent or empty CSP nonces, pass a present nonce and distinguish a
missing root from another boot error; sign-out props must fail closed when both or neither return
destinations are supplied; destination-less navigation retains its description; inputs forward an
explicit placeholder; a brand without a URL stays text; an SSR render without `document` delegates
locale selection to React Aria; and the light operating-system preference stays light when the saved
theme is `system`.

Twelve tests covering these cases were added or extended. The initial coverage run was Red against
the configured thresholds; the behavior tests passed without production changes. Focused
verification passed, and the final command sequence `oxfmt --check` on the changed test files,
`oxlint` on those files, then `bun run test:coverage` passed. Vitest reported 18 test files / 115
tests passing and 100% for statements (126/126), branches (144/144), functions (43/43) and lines
(121/121). No source exclusions, threshold changes or CI edits were made.

## Remaining work

AC-1 in `specs/public-source-coverage-completion/spec.md` is met for this revision. The requested
Minitest public/protected target remains open at 73.8802%. The full Minitest failures and errors
require classification before choosing tests or code changes; unreachable or superseded methods will
not be forced through test-only calls. Continue with route/caller and contract analysis, then TDD
each justified Ruby behavior batch.
