# CI Static Check Baseline and DatabaseConsistency Source

Observed on 2026-11-13 for step 1 and the checker-source-switch portion of step 2 in
`plans/2026-11-13-ci-static-checks-zero-work-order.md`. Finding remediation and later work-order
steps were excluded. No check finding was changed or suppressed.

## Revision and worktree

- Repository: Access; branch `feature`; `git rev-parse HEAD`:
  `727cdb560d1a55d32b14ed484d34abeda6742a61`.
- `git status --short` contained 262 paths. The worktree was already extensively modified by earlier
  authorized work; the measurements apply to that dirty tree.
- `config/credentials/` had no worktree changes. No credential file was read or edited.
- No commit or push was made. `.github/workflows/ci.yml` and `config/ci.rb` were not changed.
- `git diff --check` passed. Production build output under `public/vite/` is ignored.

## DatabaseConsistency source switch

The source switch had already been completed before this pass; it was rechecked rather than
reapplied:

- `Gemfile` uses `gem "database_consistency", require: false` without a path or FIXME.
- `Gemfile.lock` resolves the official RubyGems release 3.1.2;
  `bundle info database_consistency --path` resolves to
  `vendor/bundle/ruby/4.0.0/gems/database_consistency-3.1.2`.
- The ignored `vendor/fork/database_consistency` checkout is clean at
  `d5d1781f3d642b428d6a9654099b0cd96ce52fd8`
  (`Use scoped connections to support permanent_connection_checkout`). Its worktree diff is empty.
  Earlier discard of local checker edits and the pre-switch result are documented in
  `evidence/2026-11-12-ci-static-checks-zero-N4K7.md` and
  `evidence/2026-11-13-ci-static-switch-V2K9.md`.
- No `.database_consistency.yml` exists.
- Post-switch command:
  `env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test bundle exec database_consistency`. Exit
  1; official gem reported 76 finding lines / 83 grouped offenses. Findings were not fixed,
  excluded, or suppressed. The previous fork run was 33 lines / 38 grouped offenses; the official
  gem therefore reports 43 more lines / 45 more grouped offenses.

## Static checks

| Check                              | Command or result                                                                                                                                                                                                                                                                                                                                                      |
| ---------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Database consistency               | `env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test bundle exec database_consistency`: 76 lines, 83 grouped offenses; no configuration file.                                                                                                                                                                                                                      |
| Repository RuboCop                 | `bin/rubocop`: exit 1; 2,026 files, 56 offenses, 45 autocorrectable.                                                                                                                                                                                                                                                                                                   |
| Workflow RuboCop                   | `bundle exec rubocop --fail-fast --fail-level convention --format github`: exit 1 at `script/public_protected_method_coverage.rb:65`, `Lint/AssignmentInCondition`.                                                                                                                                                                                                    |
| Frozen string placement            | `ruby scripts/check_frozen_string_literal_directives.rb`: passed, `frozen_string_directive_check_ok=2729`.                                                                                                                                                                                                                                                             |
| Frozen string RuboCop              | Workflow command: passed, 2,729 files, no offenses.                                                                                                                                                                                                                                                                                                                    |
| ERB                                | `bundle exec erb_lint --lint-all`: passed, 541 files; parser reports Ruby 3.3 grammar with Ruby 4.0.9 runtime.                                                                                                                                                                                                                                                         |
| i18n                               | `bundle exec i18n-tasks missing`: passed; no missing translations.                                                                                                                                                                                                                                                                                                     |
| Brakeman                           | `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`: passed, 0 warnings / 0 errors (296 models, 81 controllers).                                                                                                                                                                                                                                          |
| Workflow Brakeman                  | `bundle exec brakeman -f sarif -o /tmp/umaxica-brakeman-static-baseline.sarif --no-pager --quiet -z`: passed; SARIF has 0 results.                                                                                                                                                                                                                                     |
| Gitleaks history                   | `gitleaks detect --source . --no-banner --redact --report-format json --report-path /tmp/umaxica-static-baseline-gitleaks-history.json`: exit 1; six commits scanned and 24 partial findings. Credentials Git textconv attempted a Rails boot and failed because production DB configuration is absent, so this is not a complete history scan. Redaction was enabled. |
| Gitleaks worktree diagnostic       | `gitleaks detect --no-git --source . --no-banner --redact --report-format json --report-path /tmp/umaxica-static-baseline-gitleaks-working-tree.json`: exit 1; 516 findings. This scan is not equivalent to the history scan. Redaction was enabled and no allow-list was added.                                                                                       |
| Actionlint                         | `actionlint`: exit 1; four `ubuntu-slim` labels are unknown to installed actionlint 1.7.7. Workflow was not changed.                                                                                                                                                                                                                                                   |
| Ruby dependency audit              | `bin/bundler-audit`: passed; no vulnerabilities. Workflow update scan also passed with 0 advisories; advisory DB commit `4d71b123428e33f694e805ce15351ee3d8d62ef7`.                                                                                                                                                                                                    |
| Bun dependency audit               | `bun audit` and `bun audit --audit-level=moderate`: exit 1; three moderate advisories in `glob@13.0.7`, `minimatch@10.2.6`, and `postcss-selector-parser` (`7.2.0`, `6.0.10`).                                                                                                                                                                                         |
| JavaScript format                  | `bun run format:check`: passed; 80 files.                                                                                                                                                                                                                                                                                                                              |
| JavaScript lint                    | `bun run lint`: exit 1; four TS2322 errors in the existing E2E Playwright files due to nested and top-level Playwright Core `Page` types.                                                                                                                                                                                                                              |
| JavaScript typecheck               | `bun run typecheck`: exit 1; one TS2322 error for the same Playwright type mismatch.                                                                                                                                                                                                                                                                                   |
| JavaScript aggregate               | `bun run check`: exit 1 at lint for the same four TS2322 errors. Its later checks were run separately.                                                                                                                                                                                                                                                                 |
| Typecheck coverage guard           | `bun run typecheck:verify`: passed.                                                                                                                                                                                                                                                                                                                                    |
| Dead code                          | `bun run deadcode`: passed; one existing CSS configuration hint.                                                                                                                                                                                                                                                                                                       |
| OpenAPI lint                       | `bun run openapi:lint`: passed for APP and ORG descriptions.                                                                                                                                                                                                                                                                                                           |
| OpenAPI verification               | `bun run openapi:verify`: passed; generated bundles left no tracked diff.                                                                                                                                                                                                                                                                                              |
| Production Vite build              | Workflow command `bunx vite build --mode production`: unavailable (`bunx: command not found`, exit 127). Equivalent `bun x vite build --mode production` passed after transforming 1,914 modules; the 615.63 kB chunk advisory remains.                                                                                                                                |
| Production React runtime assertion | After the build, the workflow grep found `jsx-dev-runtime` / `jsxDEV` in 54 generated artifacts; assertion fails.                                                                                                                                                                                                                                                      |
| Ruby outdated report               | `bundle outdated`: report listed newer releases; configured `                                                                                                                                                                                                                                                                                                          |     | true` makes this informational. No lockfile was updated. |
| JavaScript outdated report         | `bun outdated`: listed 9 packages with newer versions; informational. No lockfile was updated.                                                                                                                                                                                                                                                                         |

Rails tests, Vitest, Rails server smoke, and database setup are not static checks and were not run
as part of this baseline. No configuration, dependency, CI, checker, or finding remediation was
performed in this work-order item. All command outputs were kept in `/tmp`; no raw secret material
was recorded.
