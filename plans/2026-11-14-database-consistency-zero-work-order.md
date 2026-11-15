Task (umaxica-apps-cosmos-access only): bring `database_consistency` to zero findings.

## Observed on 2026-11-14 (RAILS_ENV=test, exit 1, 5 findings)

1. `UniqueIndexChecker`: `OperatorChronicle` index `uniq_operator_chronicles_sign_flow_halted` is
   unique in the database but has no uniqueness validator. (Governance reports the same finding; its
   own order handles it there.)
2. `MissingDependentDestroyChecker`: `ClientSignUpFlow` → `auth_admission_binding` has no
   association with a dependent option and no foreign key with `on_delete`.
3. `MissingDependentDestroyChecker`: `ClientOidcAuthorizationTransaction` → `secret_sign_in_flow`,
   same finding. This model was touched by today's authorization endpoint reopening; check whether
   that change introduced it.
4. `ForeignKeyCascadeChecker`: `RpBaseOrgStepUpState` → `transitions` should have
   `on_delete: :restrict` or none (2 grouped offenses).
5. `ForeignKeyCascadeChecker`: `RpBaseOrgStepUpAuditOutbox` → `attempts`, same (2 grouped).

Previous run: `evidence/2026-11-12-keep-consistency-residuals-K7C2.md` (50 findings, 17 kept).

## Work

For each finding decide from the owning ADRs and lifecycle docs what deletion or uniqueness rule is
intended, then make model and schema agree. Audit and step-up records are authoritative history
(AGENTS.md): never cascade-delete them; prefer `restrict`. For 1, the uniqueness validator must
match the partial index scope exactly. If a finding belongs to code that a 2026-11-14 order is about
to remove (for example step-up, which is out of scope today), report it with the option "remove with
that code" instead of fixing it twice.

No commit. Never print secrets, key material or environment values. Never edit
config/credentials/*.yml.enc. No push, no deploy, no Cloudflare change, no change outside this
repository. Do not disable a checker, add an exclusion or a todo file, or weaken a database
constraint to make the report pass; fix the model or the schema so both sides state the same
contract. Every schema change is a reversible migration. Tests Red first; no mocked behaviour under
test.

## Checks and report

`RAILS_ENV=test RUBY_DEBUG_ENABLE=0 bundle exec database_consistency` must exit 0 (record the
command and the finding count before and after). Then bin/rails zeitwerk:check, bin/rubocop,
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error, the changed and related tests,
bin/rails test (separate pre-existing failures; unset `POSTGRESQL_TEST_PREPARE_DATABASES` if its
stale list blocks boot and report it). Update docs/mermaid inventories and checklists if a lifecycle
or deletion rule changes.

Evidence: `evidence/YYYY-MM-DD-database-consistency-zero-XXXX.md` (full `git rev-parse HEAD`;
uncommitted changes affected results): each finding, its cause, the fix and its test, migrations,
results, owner items, and confirmation that config/credentials files are unchanged.
