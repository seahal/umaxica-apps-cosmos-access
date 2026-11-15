# Database consistency zero work order

## Run context

- Repository: `umaxica-apps-cosmos-access`.
- Full `git rev-parse HEAD`: `727cdb560d1a55d32b14ed484d34abeda6742a61`.
- The worktree was already heavily modified and contained unrelated work at task start (930 status
  entries then, 941 at final inspection); results therefore describe this combined worktree, not
  HEAD alone.
- No commit or push was made. Our migration reversibility checks used `RAILS_ENV=test` only.
  Afterward, the user ran `bin/rails db:migrate:reset` successfully; its output shows development
  and test databases were dropped, recreated, and migrated, including the three Chronicle
  migrations. No production, shared, or external database was shown as touched.
- No `config/credentials/*.yml.enc` file is modified (`git status` path check returned zero
  entries). No CI configuration was changed.

## Findings and changes

The work order recorded five initial findings. Four were corrected:

1. `ClientSignUpFlow` lacked the reverse `ClientAuthAdmissionBinding` association. Added the
   `has_many` with `dependent: :restrict_with_exception`; the existing foreign key remains
   restrictive.
2. `ClientOidcAuthorizationTransaction` lacked the reverse `ClientSignInFlow` association. Added a
   restrictive `has_one` with inverse and foreign-key declarations. The existing restrictive foreign
   key remains unchanged.
3. APP RP step-up state transitions and audit delivery attempts had `ON DELETE CASCADE`. Replaced
   both with validated `ON DELETE RESTRICT` foreign keys.
4. ORG RP step-up state transitions and audit delivery attempts had `ON DELETE CASCADE`. Replaced
   both with validated `ON DELETE RESTRICT` foreign keys.

Added reversible migrations:

- APP: `20261114081819`, `20261114081826`, `20261114081956`, `20261114082002`.
- ORG: `20261114080944`, `20261114081210`.

Each swap installs a `NOT VALID` restrictive foreign key before a separate validation migration. All
six migrations were run down and back up on the test databases; every operation exited successfully
and the final foreign keys are restrictive. Test schema dumps for `rp_base_app` and `rp_base_org`
match their live test databases.

The association and deletion rules preserve admission references, state-transition history, and
audit delivery history. Model deletion is refused by Active Record; direct SQL deletion is refused
by PostgreSQL. `restrict_with_exception` is used on step-up history associations so deletion is
restricted without depending on absent localized error translations.

Updated the Mermaid inventory and authentication checklist to record that RP step-up state and
delivery history cannot be cascade-deleted.

## Earlier remaining DatabaseConsistency finding (before final resolution)

Finding count moved from 5 to 1. Final command:

```text
env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test RUBY_DEBUG_ENABLE=0 bundle exec database_consistency
```

It exits 1 with:

```text
UniqueIndexChecker fail OperatorChronicle uniq_operator_chronicles_sign_flow_halted index is unique in the database but does not have a uniqueness validator
```

The existing partial unique index enforces uniqueness for
`(context->>'transaction_public_id', context->>'halt_generation')` when `event_id = 18`.
`OperatorChronicle` uses `JsonbKeysUniquenessValidator` for the same JSONB keys and predicate; the
owning model also validates the halted-flow context. The existing focused PostgreSQL behavior test
passes. In `database_consistency` 3.1.2, `UniqueIndexChecker` selects validators only when
`validator.kind == :uniqueness`, then compares extracted index columns with validator attributes and
scope. It does not match this custom JSONB-key validator and expression index.

No validator or database constraint was weakened and no checker suppression was added. At that
earlier checkpoint, the stored-column proposal was superseded by a less invasive option: two
PostgreSQL 18 virtual generated text columns for the JSONB keys, a standard conditional uniqueness
validator, and a matching partial unique index. The JSONB remains authoritative; the virtual columns
occupy no row storage. This still changes the schema and requires PostgreSQL 18.4 or later for the
virtual-column index behavior. Development and test use PostgreSQL 18.6, while the
staging/production major version is not yet selected. At that checkpoint implementation remained
pending approval of that exact shape and version requirement, and KEEP-target warnings were **1**.
The final resolution below supersedes this checkpoint.

### Follow-up checker audit

The command `RAILS_ENV=test RUBY_DEBUG_ENABLE=0 bundle exec database_consistency` was rerun on
2026-11-14 and reproduced the same single warning (exit 1). The locked official gem is
`database_consistency` 3.1.2. Its `UniqueIndexChecker` selects only validators whose `kind` is
`:uniqueness`, then compares validator attribute/scope names with extracted index column names. The
custom validator enforces the same JSONB key tuple and partial predicate, but its kind is
`:jsonb_keys_uniqueness`; the expression-index columns also do not equal the model's
`context`/`event_id` names. The official upstream checker source inspected for this audit uses the
same matching algorithm. This confirms a checker support gap rather than a missing database or model
uniqueness rule.

The existing PostgreSQL tests exercise duplicate rejection with differing extra JSON keys, distinct
transaction/generation tuples, malformed correlation values, and a direct database uniqueness
violation. No code or schema was changed during this follow-up. PostgreSQL's official documentation
describes virtual generated columns as occupying no storage and states that adding one does not
require a table rewrite; the 18.4 release notes document a fix for spurious errors when indexing
virtual generated columns. The version requirement remains an owner decision because the deployment
major version has not been chosen.

Sources inspected:
[official DatabaseConsistency checker](https://github.com/djezzzl/database_consistency/blob/master/lib/database_consistency/checkers/index_checkers/unique_index_checker.rb),
[PostgreSQL 18 generated columns](https://www.postgresql.org/docs/18/ddl-generated-columns.html),
[PostgreSQL 18.4 release notes](https://www.postgresql.org/docs/18/release-18-4.html), and
[PostgreSQL ALTER TABLE](https://www.postgresql.org/docs/18/sql-altertable.html).

## Earlier tests and checks (before final Chronicle resolution)

- Red evidence: the new retention tests failed while the parent FKs still cascaded. After the
  restrictive FK migrations and reverse associations, the four directly affected files passed: 26
  runs, 263 assertions, 0 failures/errors/skips. The OperatorChronicle JSONB uniqueness test also
  passed against PostgreSQL: 8 runs, 156 assertions, 0 failures/errors/skips.
- Full suite initially reported 2 failures. One was caused by the newly added Active Record delete
  restriction changing an existing test's expected exception. The test now separately asserts
  `ActiveRecord::DeleteRestrictionError` for model deletion and PostgreSQL `PG::RestrictViolation`
  for direct SQL deletion; its file passes 8 runs, 75 assertions.
- Final full suite: 5,663 runs, 37,761 assertions, 1 failure, 0 errors, 0 skips. The remaining
  failure is
  `OpenapiRouteCoverageTest#test_no_Auth_or_Visa_route_is_missing_from_its_surface_description`: the
  app route `POST /api/v0/revocation_commands` is not described in `openapi/app.yml`. This
  route/document discrepancy is outside this database task and was not changed.
- `bin/rubocop`: passed, 2,009 files inspected, no offenses. The additionally edited test file
  passed a targeted RuboCop run.
- `bin/rails zeitwerk:check`: passed (`All is good!`).
- `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`: passed, 0 security warnings.
- `test/security/invariants/lifecycle_direct_state_write_invariant_test.rb`: passed, 2 runs, 4
  assertions.
- Coverage was not measured.

## Earlier schema-drift observation (before final resolution)

`bin/rails db:verify_no_schema_drift` exits 1 and lists six dirty schema dumps: `chronicle`,
`occurrence`, `op_base_app`, `op_base_org`, `rp_base_app`, and `rp_base_org`. The task compares live
generated dumps and also rejects changed tracked dump files in the uncommitted worktree. A direct,
temporary comparison using its `SchemaDriftVerification.dump_matches?` method reports `match` for
both APP and ORG RP test dumps; no schema dump was written by that comparison. The other four listed
databases were not modified for this task.

At that earlier checkpoint the remaining work was approval and implementation of a Chronicle index
design. The final resolution below closes that finding; the OpenAPI route-description failure and
broader schema-dump work remain separate.

## Final resolution (supersedes the pending status above)

The owner directed completion after the proposed shape was discussed. The virtual-column proposal
was tested and rejected by the actual PostgreSQL 18.6 test server: PostgreSQL returned
`indexes on virtual generated columns are not supported`. That attempted migration was reversed on
the test database. The implementation therefore uses **STORED generated columns**; the JSONB
`context` remains authoritative and both generated columns derive from it only for `event_id = 18`.

Added three reversible Chronicle migrations:

- `20261114090957`: add `sign_flow_halted_transaction_public_id` and `sign_flow_halted_generation`
  as PostgreSQL STORED generated text columns; guard PostgreSQL 12+.
- `20261114091109`: concurrently add the matching partial unique index on the generated values where
  `event_id = 18`.
- `20261114091234`: concurrently remove the prior expression index after the replacement index
  exists.

The model now has a standard Rails uniqueness validator for the generated transaction ID scoped by
generated generation and the same `event_id = 18` predicate. A `before_validation` callback projects
the validated JSON values into transient model attributes so the standard validator can query before
persistence; PostgreSQL computes the stored values. The existing context validation and database
CHECK remain. Non-halt events have NULL generated values. The old expression index's equality and
partial predicate are preserved. Added English and Japanese validation labels and removed the
now-unused `JsonbKeysUniquenessValidator` (no remaining application/test references). Updated the
Chronicle SQL structure dump.

The down migrations were applied in reverse order on `RAILS_ENV=test`, then all three migrations
were reapplied successfully. At that point only the test database was migrated. Later, the user ran
the development/test reset described below; no production, shared or external database was changed.
Because STORED generated columns materialize values for existing rows, a production application of
the first migration can require a table rewrite, disk space and a strong table lock. Production
rollout has not been assessed or performed.

### TDD and final verification

- Red: the focused halted-flow test was run before the generated-column/index/model implementation:
  9 runs, 150 assertions, 4 failures showing the missing generated projection and the changed
  uniqueness validation contract.
- Green: after migration and implementation, the focused PostgreSQL test passed: 9 runs, 150
  assertions, 0 failures/errors/skips. It covers generated values, NULL projection on other events,
  duplicate model validation, database uniqueness bypass, key type equivalence, SQL-punctuation
  values, distinct tuples, malformed values and database CHECK enforcement.
- The full run exposed that an existing direct-SQL foreign-key test copied all Active Record
  attributes, including the newly generated columns. Updated only its SQL fixture attributes to omit
  generated columns while retaining the direct PostgreSQL FK assertion. Added a separate
  `insert_all!` test to prove the PostgreSQL unique index rejects duplicate rows with no Rails
  validation. Both affected model test files then passed: 23 runs, 185 assertions, 0
  failures/errors/skips.
- Final
  `env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test RUBY_DEBUG_ENABLE=0 bundle exec database_consistency`:
  exit 0; findings **0** (down from the original 5; one remained after the first four fixes). No
  checker/configuration suppression or exclusion was added. The command prints
  `No configuration files were provided` and exits successfully.
- Final full suite
  `env -u POSTGRESQL_TEST_PREPARE_DATABASES RAILS_ENV=test RUBY_DEBUG_ENABLE=0 bin/rails test`:
  5,665 runs, 37,754 assertions, 1 failure, 0 errors, 0 skips. The sole failure is the pre-existing
  `OpenapiRouteCoverageTest#test_no_Auth_or_Visa_route_is_missing_from_its_surface_description`:
  `POST /api/v0/revocation_commands` is missing from `openapi/app.yml`. The prior full run before
  this Chronicle work had the same failure.
- Final `bin/rubocop`: passed, 2,008 files inspected, no offenses. `git diff --check`, focused
  RuboCop for both changed model test files, `bin/rails zeitwerk:check`,
  `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`, and
  `bundle exec i18n-tasks missing` all exited 0. Brakeman reported 0 security warnings.
- `bin/rails db:verify_no_schema_drift` still exits 1 because five tracked schema dumps are modified
  in the broader worktree: `chronicle`, `op_base_app`, `op_base_org`, `rp_base_app`, and
  `rp_base_org`. A temporary, non-writing comparison reports all five as matching the rebuilt test
  databases; the task still rejects their uncommitted tracked diffs. Coverage was not measured.
- No lifecycle/deletion rule changed, so no Mermaid inventory or checklist update was required by
  this finding.

Final repository HEAD remains `727cdb560d1a55d32b14ed484d34abeda6742a61`; uncommitted changes
affected the results. `git status --short -- config/credentials` returned no entries. No commit or
push was made.

### Verification after the user's fresh reset

The user's successful `bin/rails db:migrate:reset` exposed fixture and dump dependencies that were
masked by the prior test database contents. It also left the configured structure dumps empty.
Re-dumped the 14 non-queue development schemas from their rebuilt databases; nine now match HEAD and
five (`chronicle`, `op_base_app`, `op_base_org`, `rp_base_app`, `rp_base_org`) remain changed and
match their rebuilt test databases. Restored `db/queue_structure.sql` to HEAD to undo the reset's
empty output; it has no net diff. No Solid Queue configuration, migration or schema was changed by
our recovery.

Fixed fresh-database test setup without weakening assertions: the halted-flow test now loads the
Chronicle event and level fixtures; `OperatorChronicleTest` uses a scalar subject ID and only
Chronicle fixtures instead of depending on other database fixtures; the OP refresh and revocation
concurrency tests load their token reference fixtures.

- After reset, `database_consistency` again exited 0 with findings **0**.
- The two Chronicle model test files passed after reset: 23 runs, 185 assertions. The OP refresh
  test passed: 1 run, 18 assertions. The targeted revocation concurrency test passed: 1 run, 46
  assertions. `DatabaseReconstructionAuthorityTest` passed: 5 runs, 43 assertions.
- Final full suite after reset and fixture/dump repair: 5,665 runs, 37,754 assertions, 1 failure, 0
  errors, 0 skips. The only failure remains the pre-existing missing OpenAPI description for
  `POST /api/v0/revocation_commands`.
- Final RuboCop, Zeitwerk, Brakeman, i18n check and `git diff --check` all passed; RuboCop inspected
  2,008 files with no offenses and Brakeman reported 0 security warnings.
- The final worktree contains 941 status entries. No credentials file is changed.
