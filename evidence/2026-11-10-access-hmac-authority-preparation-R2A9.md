# Identifier HMAC authority restoration preparation

Date: 2026-11-10 UTC. Full HEAD: `281a9e5c539bc0b89b4d37ff5bd6f102976ad4c4`. The worktree contains
extensive pre-existing uncommitted changes, including unrelated deleted RP migration files. Those
changes were preserved. Current source and installed ordinary test databases, rather than pristine
HEAD, determine the observations. No commit was made.

## Authorization and scope

The owner approved preparing corrective migrations in response to the previous turn’s explicit
request. This preparation approval did not authorize development application or retained-data HMAC
recomputation. Neither was performed. The four lookup keys, encrypted credentials and local
environment sources were not changed again in this task.

Continued the existing security/deprecation/spec workflows and used the code-review-and-quality
workflow for the final contract/diff assessment. One independent agent handled the read-only
catalog/adversarial audit and isolated verification; the parent owned migrations and documentation.
No external service was contacted.

## Read-only development findings

Used a null-logging Rails process and PostgreSQL read-only transactions. All four rotation function
bodies match their canonical definitions, including SECURITY DEFINER/plpgsql and restricted search
paths. Both audit guards and both APP binding guards match canonical bodies and enabled trigger
attachments. All audit sequences exist; no PUBLIC table-level grants were observed on source/audit
tables.

| Development catalog observation                                      | Count |
| -------------------------------------------------------------------- | ----: |
| Present rotation functions                                           |     4 |
| Functions with incorrect owners                                      |     4 |
| Missing expected isolated roles                                      |     8 |
| Functions retaining PUBLIC EXECUTE                                   |     4 |
| Audit guard definitions/attachments matching original contract       |     2 |
| APP binding guard definitions/attachments matching original contract |     2 |

Thus the repair needs role creation and narrow grants as well as ownership restoration. It must not
merely ALTER OWNER onto an unverified function. No role, function, grant, trigger, source row or
audit row was changed in development.

## Prepared artifacts

- `db/app_principals_migrate/20261110120346_restore_client_identifier_hmac_authority.rb`
- `db/org_principals_migrate/20261110120505_restore_operator_identifier_hmac_authority.rb`
- `specs/access-identifier-hmac-credentials/authority-repair.md`
- `docs/runbooks/identifier-hmac-authority-restoration.md`

The migrations were created with
`bin/rails generate migration RestoreClientIdentifierHmacAuthority --database app_zenith` and the
corresponding Operator/org_zenith command under read-only PostgreSQL boot. The generator selected
the configured principals migration directories. Existing original migration
role-isolation/ownership helpers are reused; their table/function-creating `up` methods are not
replayed. No new runtime schema builder was introduced.

Each new migration validates both owned domains before enabling authority: complete canonical
rotation and guard bodies, security/language/search-path/argument contracts, exact trigger
attachments, required audit sequence, PUBLIC table/column privileges, existing role
attributes/memberships/dependencies, object ownership and direct/default ACLs. Template-carried
embedded role identities are preserved. Unexpected bodies or authority cause refusal.

For accepted state, the migration creates only missing original NOLOGIN roles, grants original
schema USAGE, selected source-column SELECT/UPDATE, audit INSERT and sequence USAGE, restores each
definer owner, revokes PUBLIC function execution and grants the matching caller. Five-second lock
waits bound contention. Each database is transactional. No login memberships, data updates, body
replacements or trigger changes are introduced.

Rollback is fail-closed suspension, not restoration of an insecure ACL: caller/PUBLIC execution is
revoked and the function owner becomes an independent migration executor, so the embedded owner
check rejects execution. Isolated roles and narrow grants remain to preserve shared-template
dependencies and audit history. Reapplication restores operation. This behavior and the
PostgreSQL-specific SQL scope are documented in the accepted ADR amendment and runbook.

## Isolated actual-migration verification

Command: `bundle exec ruby /tmp/access_hmac_authority_verify.rb`, final exit 0. An identical ignored
review copy is retained at `tmp/access-hmac-authority-verification.rb`. No new database fleet or
environment-construction Minitest/Vitest test was introduced.

The harness exclusively locked `tmp/parallel-test-databases.lock`, connected only to ordinary TEST
APP/ORG writer databases and used named fixture migrations plus the new migrations’ public
`migrate(:up/:down)` API. Every fixture, owner/ACL/role change, controlled row insertion and
transactional audit-sequence restart was enclosed in an outer rollback. No development connection
was used by that harness.

| Test realm | Refused drift partitions | Real channel rotations | Role creation | Idempotence | PUBLIC refusal | Fail-closed down / re-up | Full rollback / schema-ACL equality |
| ---------- | -----------------------: | ---------------------: | ------------- | ----------- | -------------- | ------------------------ | ----------------------------------- |
| app        |                        8 |                      2 | passed        | passed      | passed         | passed                   | passed                              |
| org        |                        8 |                      2 | passed        | passed      | passed         | passed                   | passed                              |

The eight refusal partitions in each realm were changed rotation body, changed search path, disabled
audit guard, LOGIN-capable expected definer, excessive schema privilege, broad source-table SELECT,
default-ACL SELECT and PUBLIC column-level UPDATE. Each was rejected before authority repair; no
permissive fallback was added.

Actual authorized email and telephone rotations were exercised for both realms on controlled
disposable source fixtures. Only the selected digest changed; protected source facts were preserved
and one atomic audit record appeared per changed row. Caller direct source writes, peer-function
execution and unrelated-role/PUBLIC execution were denied. Repeating the same rotation added no
audit fact. The harness also exercised owner-self-check denial after down and successful re-up.

After the outer rollback it compared, in memory, original function/guard definitions, owners, ACLs,
table/sequence/column definitions and ACLs, trigger definitions/enabled state, row counts and audit
sequence last_value/is_called. All were unchanged; no synthetic roles remained. No source values,
row IDs, digests, keys or connection secrets were retained in diagnostics.

## Style and schema verification

Ruby syntax passed for both migrations. Scoped RuboCop passed on both migrations after formatting
corrections. Scoped `git diff --check` passed. The final permission fix was verified by the final
eight-partition harness run, not inferred from an earlier pass.

Required drift command executed without writes:

```sh
RAILS_ENV=test PGOPTIONS='-c default_transaction_read_only=on -c statement_timeout=15000' OTEL_SDK_DISABLED=true bin/rails db:verify_no_schema_drift
```

Result: exit 1, drift detected in 9 existing ordinary-test schema dumps:

- `db/app_setting_structure.sql`
- `db/app_zenith_structure.sql`
- `db/avatar_structure.sql`
- `db/chronicle_structure.sql`
- `db/occurrence_structure.sql`
- `db/op_base_app_structure.sql`
- `db/op_base_org_structure.sql`
- `db/org_setting_structure.sql`
- `db/org_zenith_structure.sql`

This is current retained test/dump baseline drift, not a committed effect of the repair: the new
migration executions and fixture drift were fully rolled back, and no migration receipt/schema
snapshot was committed to either retained database. No generated dump file was edited.
Ownership/ACL-only restoration preserves logical DDL and canonical function bodies; actual temporary
repair and rollback catalog equality was verified separately. The all-database schema gate is not
green, and the unrelated baseline drift was not repaired under this scope.

Existing identifier/rotation/search/security regression results from the preceding credential
migration remain recorded in `evidence/2026-11-10-access-identifier-hmac-credentials-M7Q2.md` (325
passing runs). They were not represented as rerun results for this preparation. This task changed no
application behavior outside the prepared migration code; verification focused on actual migration
security behavior.

## Application and remaining approval

Prepared application/rollback/verification instructions are in
`docs/runbooks/identifier-hmac-authority-restoration.md`. They name database-scoped migration
versions and require the configured DDL identity, closed affected write paths, value-free
diagnostics and post-application privilege/data checks. Development application and the two stale
retained email rows’ rehash remain pending owner approval. The earlier CI environment-source cleanup
is still outside writable `.github` access; no attempt was made to bypass its read-only mount.

No development reset, deletion, migration application, owner/ACL repair, key rotation or identifier
rehash occurred in this preparation. No commit or external service connection occurred.
