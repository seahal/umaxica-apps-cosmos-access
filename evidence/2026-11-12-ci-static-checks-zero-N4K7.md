# CI Static Checks Baseline and Checker Source Switch

Observed on 2026-11-12. This records only step 1 and the source-switch portion of step 2 in
`plans/2026-11-13-ci-static-checks-zero-work-order.md`. Finding remediation was outside this
authorized slice and was not performed.

## Revision and worktree

- Repository: Access
- Branch: `feature`
- `git rev-parse HEAD`: `727cdb560d1a55d32b14ed484d34abeda6742a61`
- The worktree was already extensively modified and uncommitted. The static baseline therefore
  reflects that worktree, including PS256 Red-test edits in `test/unit/jit/security/jwt/` and
  `test/values/security_jwt_*`; those edits contributed RuboCop offenses. The only tracked files
  changed for this evidence item are `Gemfile` and `Gemfile.lock`.
- No credentials files, `.github/workflows/ci.yml`, or `config/ci.rb` were changed.
- No commit or push was made.

## Checker source before the switch

`bundle info database_consistency --path` resolved to the ignored local checkout at
`vendor/fork/database_consistency`. Its HEAD was `d5d1781f3d642b428d6a9654099b0cd96ce52fd8`
(`Use scoped connections to support permanent_connection_checkout`), parent `3d94860`
(`Release v3.0.16`). Before discarding local edits, the nested checkout reported seven modified
tracked files and two untracked specs; `git diff --stat` reported 284 insertions and 19 deletions.
These edits were explicitly discarded with `git reset --hard HEAD` and removal of the two untracked
specs. The nested checkout is clean; its committed compatibility commit remains.

## Static baseline before the source switch

Commands were run against the current worktree. A count of zero means the command reported no
findings; failed checks are left as observed and were not fixed.

| Check                                   | Command                                                                                                                                                | Result                                                                                                                                                                                                                                                                                                             |
| --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Database consistency, local edited fork | `env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test bundle exec database_consistency`                                                             | Exit 1; no configuration files; 33 finding lines and 38 total after grouped-offense expansion.                                                                                                                                                                                                                     |
| RuboCop full report                     | `bin/rubocop`                                                                                                                                          | Exit 1; 2,012 files, 74 offenses, 62 autocorrectable. The current PS256 Red tests account for some reported offenses.                                                                                                                                                                                              |
| RuboCop CI fail-fast command            | `bundle exec rubocop --fail-fast --fail-level convention --format github`                                                                              | Exit 1 on two offenses in `test/values/security_jwt_access_token_negative_cases_test.rb` (unused `header` assignment).                                                                                                                                                                                             |
| Frozen-string directive inventory       | `ruby scripts/check_frozen_string_literal_directives.rb`                                                                                               | Passed; `frozen_string_directive_check_ok=2715`.                                                                                                                                                                                                                                                                   |
| Frozen-string RuboCop                   | `bundle exec rubocop --config .rubocop_frozen_string_literal.yml --only Style/FrozenStringLiteralComment,Style/DisableCopsWithinSourceCodeDirective .` | Passed; 2,715 files, no offenses.                                                                                                                                                                                                                                                                                  |
| ERB lint                                | `bundle exec erb_lint --lint-all`                                                                                                                      | Passed; 541 files, no errors. Parser emitted a Ruby 3.3 grammar / Ruby 4.0.9 runtime compatibility notice.                                                                                                                                                                                                         |
| i18n keys                               | `bundle exec i18n-tasks missing`                                                                                                                       | Passed; no missing translations.                                                                                                                                                                                                                                                                                   |
| Brakeman (`config/ci.rb`)               | `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`                                                                                       | Passed; 0 errors and 0 security warnings.                                                                                                                                                                                                                                                                          |
| Brakeman (workflow invocation)          | `bundle exec brakeman -f sarif -o /tmp/access-brakeman-baseline.sarif --no-pager --quiet -z`                                                           | Passed; exit 0.                                                                                                                                                                                                                                                                                                    |
| Gitleaks, git/history mode              | `gitleaks detect --source . --no-banner --redact --report-format json --report-path /tmp/access-gitleaks-baseline.json`                                | Exit 1 before a complete scan: local `.git/config` `diff.rails_credentials.textconv` invoked `bin/rails credentials:diff`, which failed to boot production because its database provider was not configured. Gitleaks reported 6 commits scanned and 24 findings in the partial scan. No secret value was emitted. |
| Gitleaks, working-tree-only diagnostic  | `gitleaks detect --no-git --source . --no-banner --redact --report-format json --report-path /tmp/access-gitleaks-working-tree-baseline.json`          | Exit 1; 516 `generic-api-key` findings. This scan is not equivalent to the workflow history scan. No secret value was emitted.                                                                                                                                                                                     |
| GitHub Actions lint                     | `actionlint` (local version 1.7.7)                                                                                                                     | Exit 1; four `ubuntu-slim` runner labels were reported unknown by this version. Workflow was not changed.                                                                                                                                                                                                          |
| JavaScript format                       | `bun run format:check`                                                                                                                                 | Passed; 77 files.                                                                                                                                                                                                                                                                                                  |
| JavaScript lint                         | `bun run lint`                                                                                                                                         | Exit 1; four TS2322 errors caused by incompatible `Page` types from nested and top-level Playwright Core packages.                                                                                                                                                                                                 |
| JavaScript typecheck                    | `bun run typecheck`                                                                                                                                    | Exit 1; the same Playwright `Page` type incompatibility appears as one TypeScript error.                                                                                                                                                                                                                           |
| JavaScript aggregate check              | `bun run check`                                                                                                                                        | Stopped at `bun run lint` for the four errors above. Its remaining static steps were run directly: `bun run typecheck:verify`, `bun run deadcode`, `bun run openapi:lint`, and `bun run openapi:verify` all exited 0.                                                                                              |
| Ruby dependency audit                   | `bin/bundler-audit check --update`                                                                                                                     | Passed; 0 vulnerable gems. Repeated after the source switch with the workflow JSON-output invocation; 0 findings.                                                                                                                                                                                                  |
| Bun dependency audit                    | `bun audit` and `bun audit --audit-level=moderate`                                                                                                     | Exit 1; three moderate advisories: `glob@13.0.7`, `minimatch@10.2.6`, and `postcss-selector-parser@7.2.0` / `6.0.10`. Not fixed in this scope.                                                                                                                                                                     |
| Production Vite build                   | `bunx vite build --mode production`                                                                                                                    | `bunx` was unavailable on this host. Equivalent `bun x vite build --mode production` passed and transformed 1,914 modules; Vite reported a 615.63 kB chunk above its 500 kB advisory threshold.                                                                                                                    |
| Production React runtime assertion      | `grep -rql 'jsx-dev-runtime\|jsxDEV' public/vite/assets` equivalent using `rg`                                                                         | Failed; markers were present in 54 generated artifacts (50 `.js` and 4 source maps). No asset changes were committed.                                                                                                                                                                                              |

Rails tests, Vitest, the Rails server smoke step, and the separate coverage job are not static
checks in this baseline slice and were not run.

## Checker source after the switch

RubyGems listed `database_consistency` 3.1.2, published 2026-10-30, as the newest release at the
time of this check ([RubyGems release listing](https://rubygems.org/gems/database_consistency)).
`Gemfile` now declares `gem "database_consistency", require: false` without a path and without the
obsolete FIXME. `bundle lock --update database_consistency` resolved 3.1.2; `bundle install` and
`bundle check` passed. The installed gem path is under
`vendor/bundle/.../gems/database_consistency-3.1.2`, and neither `Gemfile` nor `Gemfile.lock` refers
to `vendor/fork/database_consistency`.

The official gem ran successfully against this application; it did not fail on
`permanent_connection_checkout`, so no Git-pinned fallback was needed. With no DatabaseConsistency
configuration file, the post-switch command
`env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test bundle exec database_consistency` exited 1
with 76 finding lines and 83 total after grouped-offense expansion. This is 43 additional reported
lines / 45 additional grouped findings relative to the local edited fork. Findings were not changed
or suppressed, as required by the scope boundary.

The checker source is now the official released gem. The remainder of step 2 (model/schema finding
remediation) was not part of this execution request and remains pending.
