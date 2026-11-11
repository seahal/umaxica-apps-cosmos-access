# Approved Access HMAC authority repair and rehash execution

Date: 2026-11-10 UTC. Full HEAD: `281a9e5c539bc0b89b4d37ff5bd6f102976ad4c4`. Extensive pre-existing
uncommitted changes affect the runtime; no commit was made.

## Authorization and maintenance window

The owner explicitly approved applying the two prepared development authority migrations and then
recomputing the two retained email digests through the dedicated maintenance path. This record
supersedes the pending-execution status in the preparation evidence; it does not rewrite that
historical evidence. No credentials were changed again.

Stopped the existing Foreman development supervisor, its jobs/Vite children and the remaining Puma
master/workers before mutation. The normal development processes were restarted afterward with
`SKIP_DB_PREPARE=1` and all four lookup HMAC ENV names removed from the launch environment. No
database preparation/reset command ran during restart. Eight identifiable Ruby web/worker processes
were inspected afterward and had zero lookup-key ENV entries.

Read-only fresh preflight reproduced exactly one stale email in each realm and zero telephone rows.
It found no malformed or undecryptable source identifiers. Before migration application it checked
for competing active transactions on the two writer databases. Any unexpected count/configuration
caused the wrapper to stop.

The first two wrapper attempts stopped before migrations or rehash because manually initialized
Rails was initialized a second time by the Rake environment prerequisite. Corrected the wrapper to
require `config/environment` once; no application control or migration precondition was removed. The
successful command was `bundle exec ruby /tmp/access_hmac_apply_and_rehash.rb`, exit 0. Logging was
null, errors disclosed classes only, and the output report contained only versions/counts/flags.

## Applied migrations

| Writer          | Version          | Applied |
| --------------- | ---------------- | ------- |
| AppZenithRecord | `20261110120346` | yes     |
| OrgZenithRecord | `20261110120505` | yes     |

The wrapper invoked the standard database-scoped `db:migrate:up:app_zenith` and
`db:migrate:up:org_zenith` Rake tasks with each exact VERSION. Only each approved version receipt
was added; no existing version receipt disappeared. It verified that all four Source tables, both
audit tables and the selected function bodies/security attributes were unchanged by the authority
migrations.

All four functions then had valid dedicated owners, matching caller EXECUTE, no PUBLIC EXECUTE and
no residual definer schema CREATE. No login memberships were granted.

## Rehash results

Used `IdentifierHmacEmergencyRotation` with separate explicit maintenance connections, matching the
canonical Rake task’s implementation and restricted caller selection. Both maintenance connections
held write-blocking SHARE ROW EXCLUSIVE locks across their realm’s email and telephone Sources
before recomputation; ordinary Source reads remained separate. Each selected operation assumed only
its channel caller. Both database-local transactions were validated before commit. There is no
distributed atomicity claim across the two database commits; the accepted retry/recovery plan
remained applicable.

| Table                 | Rows | Stale before | Updated | Stale after | Exact lookup matches |
| --------------------- | ---: | -----------: | ------: | ----------: | -------------------: |
| `client_emails`       |    1 |            1 |       1 |           0 |                    1 |
| `client_telephones`   |    0 |            0 |       0 |           0 |                    0 |
| `operator_emails`     |    1 |            1 |       1 |           0 |                    1 |
| `operator_telephones` |    0 |            0 |       0 |           0 |                    0 |

All raw Source columns other than the selected digest columns were compared in memory and remained
identical, including owner, encrypted readable data, binding state and timestamps. No source value,
row ID or digest was printed or persisted in the report.

| Audit table                           | Before | Added | After |
| ------------------------------------- | -----: | ----: | ----: |
| `client_identifier_rotation_audits`   |      0 |     1 |     1 |
| `operator_identifier_rotation_audits` |      0 |     1 |     1 |

Existing audit rows were preserved. New records were email-only, one per changed row; no telephone
audit record appeared. Post-commit repeated operation across all four channels updated zero rows,
reported zero failures and left audit counts unchanged. Credential-file digests were compared in
memory before/after and were unchanged; no credential fingerprint or value was retained.

## Restart and verification

Fresh read-only model inspection after restart confirmed zero stale/missing/malformed/undecryptable
digests and that both existing emails resolve to their original records through the public
`find_by_address` API. The running development server returned:

| Auth App request     | HTTP status |
| -------------------- | ----------: |
| `/health/liveness`   |         200 |
| `/sign/in`           |         302 |
| `/sign/in/email/new` |         400 |

The guarded email entry without ceremony prerequisites returns 400; this is not an end-to-end
provider sign-in claim. The actual existing-email model lookups succeeded after recomputation. Web,
Vite and job process trees were restored. A debugger address-in-use warning appeared in job startup
logs; the supervisor and its normal worker/dispatcher/scheduler processes remained running, and the
web checks passed. No unrelated debugger configuration was changed.

Scoped RuboCop on the two corrective migrations and the corrected ignored maintenance wrapper passed
after correcting wrapper style. Earlier 325 identifier/search/security tests and the isolated
migration refusal/rollback checks remain in their prior evidence; they are not claimed as rerun
results here. No test data was altered by the development rehash.

## Schema artifacts and remaining limits

Development configuration intentionally sets `dump_schema_after_migration = false`, so the normal
migration tasks did not write snapshots. Generated both selected development dumps explicitly
through `DatabaseTasks.dump_schema` in temporary storage under read-only PostgreSQL. Each contained
exactly its one new migration receipt and no missing prior receipts. Both also differed from the
repository’s pre-existing snapshot beyond the new receipt, so those generated candidates were not
copied into the worktree or hand-edited. No tracked schema dump was changed. The pre-existing
nine-file ordinary-test schema drift remains recorded in the preparation evidence; the all-database
schema gate remains non-green.

The original credential migration’s CI environment-source deletion is still blocked by the read-only
`.github` mount. This execution completed the approved development authority/data transition,
without pretending that unrelated CI/schema cleanup is complete. No development database
deletion/reset, retained-data erasure, credential rewrite, commit or external service connection
occurred.
