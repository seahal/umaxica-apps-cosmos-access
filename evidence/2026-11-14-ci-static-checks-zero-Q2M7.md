# CI Static Checks: Final Remediation Record

## Scope and revision

- Repository: `umaxica-apps-cosmos-access`, branch `feature`.
- `git rev-parse HEAD`: `727cdb560d1a55d32b14ed484d34abeda6742a61`.
- The worktree was already extensively uncommitted and those changes affected the results. No commit
  or push was made.
- This completes the requested static-check work after the source-switch portion recorded in
  `2026-11-13-ci-static-checks-source-switch-D8K4.md`. It does not claim every check is zero.
- `.github/`, `config/credentials/`, and `config/ci.rb` were not changed. No DatabaseConsistency
  configuration, checker suppression, allow-list, or new TODO entry was added. The RuboCop TODO file
  was removed as the work order requires.
- The final Ruby refactor removed 17 inline `rubocop:disable` directives from the in-progress diff;
  the current diff adds none. No checker or model was excluded to lower counts.

## Check results

| Check                               |                                                                                                                                      Baseline |                                                                                                                                                                                                                Final result | Command / notes                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| ----------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------: | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------: | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| DatabaseConsistency                 |                                                                                    Official gem 3.1.2: 76 finding lines / 83 grouped offenses |                                                                                                                                                                               Test DB: 5 finding lines / 7 grouped offenses | `RAILS_ENV=test bundle exec database_consistency`; no checker configuration. The previous local fork had 33 / 38. A separate accidental run with no explicit Rails environment selected the default development connection and reported 11 finding lines / 16 grouped offenses; it is diagnostic only, not the acceptance result. No development database change was made.                                                                                                                                                                  |
| Repository knowledge links          |                                                                                                                 Executable missing (exit 127) |                                                                                                                                                                     Executable restored; 37 unresolved links in 5 documents | `scripts/check-repository-knowledge`; exit 1. Restored from local Git history because sibling repositories were not checked out here. The linked historical behavior documents were left unchanged.                                                                                                                                                                                                                                                                                                                                         |
| RuboCop                             |                                                                                                                                   68 offenses |                                                                                                                                                                                           0 offenses; 1,996 files inspected | `bundle exec rubocop --fail-level convention`. `.rubocop_todo.yml` and its inheritance entry were removed.                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| Frozen string directive placement   |                                                                                                       2,725 directives checked, no violations |                                                                                                                                                                                     2,702 directives checked, no violations | `ruby scripts/check_frozen_string_literal_directives.rb`; the reduced count reflects removed source files.                                                                                                                                                                                                                                                                                                                                                                                                                                  |
| Frozen string RuboCop               |                                                                                                                      2,725 files, no offenses |                                                                                                                                                                                                    2,703 files, no offenses | `bundle exec rubocop --config .rubocop_frozen_string_literal.yml --only Style/FrozenStringLiteralComment,Style/DisableCopsWithinSourceCodeDirective .`                                                                                                                                                                                                                                                                                                                                                                                      |
| ERB Lint                            |                                                                                                                          541 files, no errors |                                                                                                                                                                                                        541 files, no errors | `bundle exec erb_lint --lint-all` (16 linters). Parser still reports Ruby 3.3 grammar with Ruby 4.0.9 runtime.                                                                                                                                                                                                                                                                                                                                                                                                                              |
| Missing translations                |                                                                                                                                             0 |                                                                                                                                                                                                                           0 | `bundle exec i18n-tasks missing`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| Brakeman                            |                                                                                                                         0 warnings / 0 errors |                                                                                                                                                                                                       0 warnings / 0 errors | `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| Gitleaks history                    |                                                                                                        24 redacted findings in a partial scan |                                                                                                                                                                                      24 redacted findings in a partial scan | `gitleaks detect --source . --no-banner --redact --report-format json`. Git credential text conversion prevented a complete history scan. No finding values were recorded.                                                                                                                                                                                                                                                                                                                                                                  |
| Gitleaks worktree                   |                                                                                                                       516 redacted detections |                                                                                                                                                                                                     516 redacted detections | `gitleaks detect --no-git --source . --no-banner --redact --report-format json`. Metadata-only grouping identifies rule `generic-api-key`: 404 findings in ignored temporary reports/snapshots, 110 in repository research/archive/test files, and 2 in `.env`. No values were inspected or recorded, and no allow-list was added.                                                                                                                                                                                                          |
| Actionlint                          |                                                                                           4 unknown `ubuntu-slim` runner diagnostics on 1.7.7 |                                                                                                                                                                                                     0 diagnostics on 1.7.12 | The official 1.7.12 binary was checksum-verified before use. Workflow files were not changed.                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| Ruby dependency audit               |                                                                                                                             0 vulnerable gems |                                                                                                                                                                                                           0 vulnerable gems | `bin/bundler-audit check --update --format json`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| Bun dependency audit                |                                                                                                                         3 moderate advisories |                                                                                                                                                                                         0 advisories (388 packages checked) | `bun audit --audit-level=moderate`. Removed the unused `linkinator` dependency and its Knip ignore entry; added a scoped `@tailwindcss/typography` override from `postcss-selector-parser` 6.0.10 to patched 6.1.5. The official advisory lists 6.1.5 as patched: [GHSA-rj75-hqrm-r3gf](https://github.com/postcss/postcss-selector-parser/security/advisories/GHSA-rj75-hqrm-r3gf). The nested override uses Bun 1.4's documented syntax and updates `bun.lock` to lockfile version 3: [Bun overrides](https://bun.com/docs/pm/overrides). |
| JavaScript formatting               |                                                                                                                                 80 files pass |                                                                                                                                                                                                               80 files pass | `bun run format:check`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| JavaScript lint                     |                                                                                                       4 TS2322 errors in Playwright E2E specs |                                                                                                                                                                                                                    0 errors | `bun run lint`. The affected callbacks now use the matching Playwright `Page` type; `playwright-core` is a direct dev dependency at the aligned version.                                                                                                                                                                                                                                                                                                                                                                                    |
| JavaScript typecheck                |                                                                                                                                1 TS2322 error |                                                                                                                                                                                                                    0 errors | `bun run typecheck`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| Typecheck coverage guard            |                                                                                                                                          Pass |                                                                                                                                                                                                                        Pass | `bun run typecheck:verify`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                 |
| Dead-code scan                      |                                                                                                              Pass, one CSS configuration hint |                                                                                                                                                                                                             Pass, same hint | `bun run deadcode`.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| OpenAPI lint                        |                                                                                                                                          Pass |                                                                                                                                                                                                                        Pass | `bun run openapi:lint` for APP and ORG.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| OpenAPI verify / aggregate JS check |                                                                                              Previously passed against its then-current index | Raw `bun run check` exits at `openapi:verify` because the two generated bundles differ from the dirty worktree index; the entire check passes with a temporary alternate index containing the current deterministic bundles | No real index or staging state was changed. A second bundle run produced stable output.                                                                                                                                                                                                                                                                                                                                                                                                                                                     |
| Production Vite build               | Build passed; the previous surface chunk was 615.63 kB and a whole-directory scan found 54 development-runtime markers in old local artifacts |                                          Build passed; the current manifest references 3 present JavaScript assets with 0 development-runtime markers; surface chunk is 404,978 bytes. Old ignored artifacts were retained. | `bun run build`; current generated assets were checked through the manifest.                                                                                                                                                                                                                                                                                                                                                                                                                                                                |

## DatabaseConsistency findings kept for owner review

The official checker reports five findings grouped into seven offenses. These were not hidden or
changed to satisfy the checker:

1. `OperatorChronicle` has a PostgreSQL partial expression unique index for exactly-once
   `SIGN_FLOW_HALTED` records. `JsonbKeysUniquenessValidator` enforces the corresponding JSONB key
   pair and is covered by model and direct-constraint tests. The checker does not recognize this
   custom validator. Owner options: add support for this validator upstream to the official checker,
   or provide a checker-recognized Rails validation with provably identical JSONB pair semantics. Do
   not remove or widen the partial index.
2. `RpBaseOrgStepUpState#transitions` and `RpBaseOrgStepUpAuditOutbox#attempts` use Rails
   `dependent: :restrict_with_error`, while their RP database foreign keys were explicitly created
   with `ON DELETE CASCADE` (two grouped offenses for each relation). The accepted OP-mediated
   step-up instruction requires additive migrations and preserving transition/audit history; it does
   not decide parent deletion behavior for these relations. Owner options: make the model perform
   `delete_all` to match the current database cascade, or add a forward migration to
   `ON DELETE RESTRICT` to preserve the model restriction. Choose the deletion policy and retention
   consequence before changing either side.
3. `ClientOidcAuthorizationTransaction#secret_sign_in_flow` has an optional historical reference
   protected by `ON DELETE RESTRICT`; `OidcAuthorizationTransactionPurger` holds secret-linked
   records when Governance cannot verify the external retention facts. The checker does not accept
   restrictive FKs for this finding. Owner options: teach the official checker to recognize this
   restrictive-retention contract, or approve a changed retention lifecycle before adding a
   cascading/nullifying dependent action.
4. `ClientSignUpFlow#auth_admission_binding` is required and protected by `ON DELETE RESTRICT`;
   `AuthAdmissionBindingPurger` verifies terminal cleanup and deletes eligible child flows before
   their binding. The checker does not treat this restrictive lifecycle as a satisfying dependent
   action. Owner options: add official checker support for the child-first lifecycle/RESTRICT
   relationship, or approve a changed lifecycle before replacing it with cascade/nullify behavior.

The two associations in items 3 and 4 are on `op_base_app`; that connection was listed as out of
scope in the preceding database-removal task. No schema or lifecycle contract was changed to clear
these warnings.

## Other static work and migrations

- Added `scripts/check-repository-knowledge` so the existing `config/ci.rb` step runs. Its 37
  remaining broken links are in `docs/checklists/authentication-flow-integrity.md`,
  `docs/checklists/authentication.md`, `docs/checklists/avatar-ownership.md`,
  `docs/checklists/contact-identifiers.md`, and `docs/checklists/identifier-contracts.md`. Those
  documents describe behavior already assigned for documentation follow-up and were not rewritten
  here.
- Four DDL-only migrations from the remediation pass add required indexes or remove redundant
  indexes: `20261114010255_add_client_auth_admission_base_token_index`,
  `20261114010250_add_operator_session_limit_foreign_key_indexes`,
  `20261114010731_remove_redundant_rp_base_app_step_up_indexes`, and
  `20261114010242_remove_redundant_rp_base_org_step_up_indexes`. They do not update or delete table
  rows. Disposable test-database up/down/up verification was recorded during that pass.
- The Herb comparison was read-only; no adoption or tool switch was made. ERB Lint checks 541 files
  with 16 linters, had no errors, and took about 1.23 seconds. Herb 0.11.2 discovered 54 files and
  reported 3,566 errors, 6,142 warnings, 1 informational item (9,709 total offenses), across 42
  failing files, in about 7.2 seconds. The sets of discovered files and rules are not equivalent, so
  the counts are not direct quality comparisons. Herb's Rails 8.2 engine check and editor/LSP
  support are useful, but its current lint result does not support replacing the passing ERB Lint
  check. `bin/rails herb:check` passed template compilation.
- Bun advisory remediation: `linkinator` had no call site outside its own dependency declaration and
  a `knip.json` ignore entry, so both were removed. That removes its `glob@13` / `minimatch@10`
  vulnerable chain. `@tailwindcss/typography@0.5.20` declares `postcss-selector-parser@6.0.10`
  exactly; the nested override selects patched `6.1.5` only for that parent.
  `bun install --ignore-scripts` updated the lockfile without invoking package lifecycle hooks.
  `bun audit --audit-level=moderate` then reported no vulnerabilities across 388 packages.
  `bun update --latest` dry run had shown no patched parent release, so the scoped dependency
  changes were needed.
- The initial dependency update dry-run invoked the package `prepare` script, which ran Lefthook and
  synchronized local pre-commit and pre-push hooks. The pre-run contents were not captured, so no
  restoration was attempted. That probe was a dry run; the later dependency remediation used
  `bun install --ignore-scripts`. No workflow or tracked hook configuration changed.
- A temporary diagnostic assertion added during this run, requiring the Rails test logger to emit a
  `client_tokens` SQL line, failed: the isolated test environment produced an empty in-memory SQL
  log despite the DEBUG logger. That new diagnostic assertion was removed; no pre-existing assertion
  was weakened, and no test or production environment configuration was changed to force SQL output.
  Existing refresh-digest filter assertions remain, and the prior evidence's separate debug-level
  SQL-log probe remains the only observed non-vacuous logging check for this boundary.

## Test results

- Client assertion PS256-only cutover and its Red/Green coverage are recorded in
  `2026-11-13-client-assertion-ps256-only-P5Q2.md`: PS256 acceptance; ES384, RS256 and PS384
  rejection; 3,071-bit rejection and 3,072-/3,073-bit acceptance; PS256-only Discovery metadata.
  Focused result: 67 runs, 286 assertions, no failures or errors.
- The full-suite classification remains 103 deletes for removed subjects, 86 updates for changed
  contracts, 7 code fixes, and 1 failure blocked by excluded Stage 4 work; details are in
  `2026-11-14-full-test-suite-triage-F3Q8.md`.
- The revoke timing test now passes the supported decision time explicitly and asserts the persisted
  second exactly; it no longer compares two independently advancing clocks. Focused token-status
  result: 22 runs, 107 assertions, no failures or errors.
- Final focused logger test:
  `env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test bin/rails test test/unit/security/filter_parameter_logging_test.rb`
  passed **6 runs, 39 assertions, 0 failures, 0 errors, 0 skips**. The attempted positive SQL-output
  diagnostic was not retained because this test environment produced no SQL logger output.
- No-suppression Red/Green: tests first failed when asserting immutable ceremony/OIDC surface
  declarations and the Sign Entry declaration API boundary. After replacing mutable class attributes
  with frozen readers/closures, the focused set passed **32 runs, 401 assertions, 0 failures, 0
  errors, 0 skips**. The subsequent full RuboCop run inspected 1,996 files with 0 offenses.
- Final Rails suite after the final test-source state: **5,574 runs, 36,876 assertions, 1 failure, 0
  errors, 0 skips**. The only failure is
  `OpenapiRouteCoverageTest#test_no_Auth_or_Visa_route_is_missing_from_its_surface_description`, for
  `POST /api/v0/revocation_commands`; the focused route suite reproduced it at **3 runs, 10
  assertions, 1 failure**. ADR decision 18 supersedes the server-push design; removing the route and
  callers belongs to Jump handoff Stage 4, explicitly out of scope. The test and endpoint were left
  intact. The suite is therefore not fully green. Full result and classification correction:
  `2026-11-14-full-test-suite-correction-H6J2.md`.
- JavaScript coverage suite: 18 test files and 115 tests passed.
- `git diff --check` passed after the implementation and evidence updates.

## Owner items and limits

- Decide the five DatabaseConsistency findings above without weakening the index, referential
  integrity, retention, or lifecycle behavior.
- Triage 24 partial-history and 516 worktree Gitleaks detections from the redacted reports. The
  worktree report includes local `.env` content and ignored temporary snapshots; the history scan is
  incomplete. No finding was allow-listed or edited without reviewing its value, which this task
  forbids printing.
- Resolve the 37 stale documentation links in the five listed checklists through their documentation
  owner.
- Complete the excluded Jump handoff Stage 4 route removal so the final Rails suite can become
  green.
- A whole-directory scan still sees 54 old ignored production artifacts with development-runtime
  markers; the current manifest assets are clean, and the old artifacts were retained.
- The accidental default-environment DatabaseConsistency invocation was followed by a read-only
  development connection-locality probe that did not complete with a safe locality result. No
  migration, reset, drop or write command was run against development, and no development rows were
  changed. The additional 11/16 diagnostic findings remain unclassified until the development
  connection can be safely identified.

One inspection tool output displayed two workflow-configured environment settings, contrary to the
no-environment-values instruction. They were not secrets and are not quoted or persisted in this
evidence. Rails test boot diagnostics also printed test database catalog metadata in tool output; it
is not copied into this record. No credentials or secret values were printed or recorded here, and
no config/credentials or key material was edited. Subsequent commands did not print environment
values. The dry-run's local Git hook synchronization is recorded above. No workflow file was edited,
and no commit or push was made.
