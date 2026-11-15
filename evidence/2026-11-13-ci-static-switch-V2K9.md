# CI Static Baseline and DatabaseConsistency Source Switch

Observed on 2026-11-13 for steps 1 and the checker-source-switch portion of step 2 in
`plans/2026-11-13-ci-static-checks-zero-work-order.md`. Finding remediation and all later work-order
steps were excluded from this execution.

## Revision and worktree

- Repository: Access; branch: `feature`.
- `git rev-parse HEAD`: `727cdb560d1a55d32b14ed484d34abeda6742a61`.
- The worktree was dirty: 194 changed paths at evidence capture (112 modified, 68 deleted, 14
  untracked). This includes prior authorized work and coverage tests; the results are for this
  worktree, not a clean checkout.
- `config/credentials/` was clean. No workflow, `config/ci.rb`, credential, or application finding
  was modified for this execution. No commit or push was made.
- Production Vite build output is ignored; OpenAPI verification left no tracked OpenAPI changes.

## Checker source switch and counts

The source switch had already been completed in the preserved worktree. It was reverified:

- `Gemfile` declares `gem "database_consistency", require: false`, with no `path:` or FIXME.
- `Gemfile.lock` resolves official `database_consistency` 3.1.2.
- `bundle info database_consistency --path` resolves to
  `vendor/bundle/ruby/4.0.0/gems/database_consistency-3.1.2`.
- `vendor/fork/database_consistency` is clean at compatibility commit
  `d5d1781f3d642b428d6a9654099b0cd96ce52fd8`; local edits were discarded in the earlier execution
  recorded by `evidence/2026-11-12-ci-static-checks-zero-N4K7.md`.
- With no DatabaseConsistency configuration, the current official-gem run reported 76 finding lines
  and 83 grouped offenses. The recorded pre-switch local-fork result was 33 lines and 38 grouped
  offenses, a difference of 43 lines and 45 grouped offenses. No finding was fixed, excluded, or
  suppressed.

## Static checks

Counts and statuses below are current-worktree observations. Rails tests and other test jobs were
not part of this static-check baseline.

| Check                                  | Command                                                                                                                                                | Result                                                                                                                                                                                                       |
| -------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| Database consistency                   | `env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test bundle exec database_consistency`                                                             | Exit 1; no configuration; 76 finding lines, 83 grouped offenses.                                                                                                                                             |
| RuboCop (`config/ci.rb`)               | `bin/rubocop`                                                                                                                                          | Exit 1; 2,013 files, 61 offenses, 50 autocorrectable.                                                                                                                                                        |
| RuboCop (workflow)                     | `bundle exec rubocop --fail-fast --fail-level convention --format github`                                                                              | Exit 1; four Layout offenses in the already modified `test/models/public_method_contract_values_test.rb`.                                                                                                    |
| Frozen string placement                | `ruby scripts/check_frozen_string_literal_directives.rb`                                                                                               | Passed; `frozen_string_directive_check_ok=2716`.                                                                                                                                                             |
| Frozen string RuboCop                  | `bundle exec rubocop --config .rubocop_frozen_string_literal.yml --only Style/FrozenStringLiteralComment,Style/DisableCopsWithinSourceCodeDirective .` | Passed; 2,716 files, no offenses.                                                                                                                                                                            |
| ERB lint                               | `bundle exec erb_lint --lint-all`                                                                                                                      | Passed; 541 files, no errors. Parser emitted its Ruby grammar/runtime compatibility notice.                                                                                                                  |
| i18n                                   | `bundle exec i18n-tasks missing`                                                                                                                       | Passed; no missing translations.                                                                                                                                                                             |
| Brakeman (`config/ci.rb`)              | `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`                                                                                       | Passed; zero errors and zero security warnings.                                                                                                                                                              |
| Brakeman (workflow SARIF)              | `bundle exec brakeman -f sarif -o /tmp/access-brakeman-current.sarif --no-pager --quiet -z`                                                            | Passed.                                                                                                                                                                                                      |
| Gitleaks (history)                     | `gitleaks detect --source . --no-banner --redact --report-format json --report-path /tmp/access-gitleaks-current.json`                                 | Exit 1; credentials Git textconv failed and prevented a complete scan. Six commits were scanned and 24 findings were reported in the partial scan. Redaction was enabled; no secret value was recorded here. |
| Gitleaks (working tree diagnostic)     | `gitleaks detect --no-git --source . --no-banner --redact --report-format json --report-path /tmp/access-gitleaks-working-tree-current.json`           | Exit 1; 516 findings. This is not equivalent to the history scan. Redaction was enabled.                                                                                                                     |
| GitHub Actions lint                    | `actionlint`                                                                                                                                           | Exit 1; installed actionlint 1.7.7 reported four `ubuntu-slim` labels as unknown. Workflow was not changed.                                                                                                  |
| JavaScript format                      | `bun run format:check`                                                                                                                                 | Passed; 80 files.                                                                                                                                                                                            |
| JavaScript lint                        | `bun run lint`                                                                                                                                         | Exit 1; four TS2322 errors in unchanged Playwright E2E files due to nested and top-level Playwright Core `Page` types.                                                                                       |
| JavaScript typecheck                   | `bun run typecheck`                                                                                                                                    | Exit 1; one TypeScript error from the same Playwright type incompatibility.                                                                                                                                  |
| JavaScript aggregate check             | `bun run check`                                                                                                                                        | Exit 1 at lint for the same four TS2322 errors. Its later steps were run separately.                                                                                                                         |
| Typecheck coverage guard               | `bun run typecheck:verify`                                                                                                                             | Passed.                                                                                                                                                                                                      |
| Dead code                              | `bun run deadcode`                                                                                                                                     | Passed.                                                                                                                                                                                                      |
| OpenAPI lint                           | `bun run openapi:lint`                                                                                                                                 | Passed.                                                                                                                                                                                                      |
| OpenAPI verification                   | `bun run openapi:verify`                                                                                                                               | Passed; no tracked bundle diff remained.                                                                                                                                                                     |
| Ruby dependency audit (`config/ci.rb`) | `bin/bundler-audit`                                                                                                                                    | Passed; no vulnerable gems.                                                                                                                                                                                  |
| Ruby dependency audit (workflow)       | `bin/bundler-audit check --update --format json --output /tmp/access-bundler-audit-current.json`                                                       | Passed; no vulnerable gems.                                                                                                                                                                                  |
| Bun dependency audit                   | `bun audit --audit-level=moderate` and `bun audit`                                                                                                     | Exit 1; three moderate vulnerabilities: `glob@13.0.7`, `minimatch@10.2.6`, and `postcss-selector-parser` (`7.2.0`, `6.0.10`).                                                                                |
| Production Vite build                  | `bunx vite build --mode production`; then `bun x vite build --mode production`                                                                         | `bunx` was unavailable (127); equivalent `bun x` build passed. The 615.63 kB chunk advisory remains.                                                                                                         |
| Production React runtime assertion     | `rg -l 'jsx-dev-runtime                                                                                                                                | jsxDEV' public/vite/assets`                                                                                                                                                                                  | Failed; markers were found in 54 generated artifacts (50 JavaScript files and 4 source maps). |

No CI, dependency, generated-source, or finding remediation was performed. Environment setup, Rails
server smoke, Vitest, and Rails tests were not run because they are outside the requested
static-only slice.
