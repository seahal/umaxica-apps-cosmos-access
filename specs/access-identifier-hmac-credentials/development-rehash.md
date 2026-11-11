# Development identifier rehash decision and execution plan

Status: executed under explicit owner approval on 2026-11-10. Actual results:
[execution evidence](../../evidence/2026-11-10-access-hmac-approved-execution-K4V8.md). Scope:
Access development only. No credential values, identifiers, digests, row IDs or connection URLs
belong in output, diagnostics or evidence.

## Observed input

The read-only preflight after credential rotation found:

| Table               | Rows | Stale digests | Malformed identifiers | Decryption failures |      Finalized bindings |
| ------------------- | ---: | ------------: | --------------------: | ------------------: | ----------------------: |
| client_emails       |    1 |             1 |                     0 |                   0 |                       0 |
| operator_emails     |    1 |             1 |                     0 |                   0 | Not an APP binding axis |
| client_telephones   |    0 |             0 |                     0 |                   0 |                       0 |
| operator_telephones |    0 |             0 |                     0 |                   0 | Not an APP binding axis |

Both email lookup methods execute without error but cannot match the old digests under the new keys.
Do not treat the successful development boot as successful existing-account sign-in verification.

## Requested backfill and contract conflict

`IdentifierBlindIndexBackfill.new.call` exists in `app/services/identifier_blind_index_backfill.rb`;
there is no dedicated Rake task with that name. It visits all four models and saves changed rows
through ordinary Active Record updates, using the existing `save!(validate: false)` call. It does
not use the audited maintenance function path.

[The accepted rotation ADR](../../adr/identifier-hmac-emergency-rotation.md) requires restricted,
channel-specific SECURITY DEFINER functions and atomic audit facts for retained-data HMAC rotation.
The ordinary backfill also cannot rotate protected finalized APP bindings. No validation, trigger,
immutability or authorization control has been changed to make that legacy service usable.

**Approved decision:** use the existing canonical `identifier_hmac:rotate` maintenance path for the
two stale development email rows instead of the legacy ordinary backfill writer. This preserves the
requested recomputation behavior and the accepted audit/ownership boundary. If the owner requires
`IdentifierBlindIndexBackfill` itself, stop for an explicitly scoped redesign of that writer; do not
run its ordinary saves against retained development data.

## Prerequisite at planning time (subsequently repaired)

Read-only PostgreSQL catalog inspection found all four rotation functions present, but none has an
owner matching the required realm/channel-specific definer prefix and suffix. Caller-role
membership/execution checks were not attempted after owner validation failed. The canonical task
would reject this state before recomputation. No ownership, grants, triggers or function bodies were
modified.

The owner subsequently authorized preparation of the corrective migrations. Preparation is complete;
the owner later approved development application and recomputation, both now completed. Replaying
the original migration `up` wholesale is unsafe because it also creates existing audit tables; do
not reset the database or delete audit history to make it pass. Relevant original migrations are
`db/app_principals_migrate/20261008025001_add_client_identifier_hmac_maintenance.rb` and
`db/org_principals_migrate/20261008025009_add_operator_identifier_hmac_maintenance.rb`. The repair
must review existing roles, memberships, dependencies, schema/table grants, function owners/search
paths/EXECUTE ACLs and binding/audit guards against those definitions, then change only proven
drift. The two corrective migrations and their isolated results are described in
[authority repair](authority-repair.md). Both were subsequently applied to development; the
audit-preserving rehash is complete.

## Procedure after approval and prerequisite repair only

1. Freeze all APP/ORG email and telephone mutation paths and workers for the maintenance window. No
   dual-key mixed-write interval is safe for a single-column uniqueness index. Coordinate this with
   the owner; no shared server or worker was stopped by this task.
2. Restart the maintenance process with the new encrypted credentials. Verify all four lookup keys
   resolve directly from credentials and none is supplied by ENV. Retain the current readable-data
   encryption keys unchanged. Never print credential contents.
3. Re-run the count-only read-only preflight. Stop and report if the observed four-table counts
   differ from the table above, if a source value cannot decrypt/normalize, or if a uniqueness
   conflict is detected. Confirm no concurrent identifier writer is admitted.
4. Verify the four installed function owners, channel-specific caller permissions and audit tables
   under the actual development databases. Use only existing local maintenance authority; no role
   grants, trigger changes or DDL are authorized here.
5. Supply `IDENTIFIER_HMAC_MAINTENANCE_DATABASE_URL` through the operator's secure process
   environment for the selected writer database. Do not paste it into a command argument or record.
   With the APP maintenance connection selected, run:

   ```sh
   bundle exec ruby tmp/access-identifier-hmac-maintenance.rb app email
   bundle exec ruby tmp/access-identifier-hmac-maintenance.rb app telephone
   ```

   With the ORG maintenance connection selected, run:

   ```sh
   bundle exec ruby tmp/access-identifier-hmac-maintenance.rb org email
   bundle exec ruby tmp/access-identifier-hmac-maintenance.rb org telephone
   ```

   The prepared wrapper uses null application/SQL logging before boot and invokes the existing
   `identifier_hmac:rotate` Rake task; only its Ruby syntax was checked, and it was not executed.
   The existing command rejects an absent maintenance connection, validates the actual function
   owner, and assumes only its selected channel's caller role. It raises on failed rows; capture
   only operation status and aggregate counts, never a raw exception/SQL bind dump. Telephone
   targets are currently empty and should produce no changes or audit insertions.

6. Verify each table has zero stale, missing or malformed digests; requery each existing email
   through `find_by_address` and require that it returns its original owner. Compare source
   ownership, encrypted PII, binding state and timestamps in memory before/after; only digest
   columns may change. Verify two new rotation-audit records in aggregate, one per changed email
   row, and no telephone audit insertions. Do not print row IDs or audit payloads.
7. Repeat the selected operation to verify no additional changed rows or audit events. Record
   before/updated/after counts. Restart the development server on new credentials and repeat health,
   sign-in-entry and existing-email lookup checks before reopening the affected writes.

## Stop and recovery conditions

The supported operation commits each row atomically with its audit fact, not all four channels in
one transaction. A later failure can therefore leave a partial rotation. Keep writes frozen,
recount, investigate without disclosing values, and resume the same new-key operation: already
current rows are no-ops. An audit-insert failure rolls back its row update. Duplicate constraints,
compare-and-swap conflicts, permission errors or unreadable source ciphertext stop the run.

No reset, deletion, old-key restoration, database schema change or audit erasure is proposed.
Readable encrypted source identifiers and encryption keys remain unchanged, allowing recomputation
under the new HMAC keys. If a source cannot decrypt, stop for a separate recovery decision rather
than dropping that row. Existing temporary old-key inventories do not constitute permission to
restore shared old keys.
