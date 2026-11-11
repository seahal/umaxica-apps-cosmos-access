# Identifier maintenance authority restoration

Status: verified for the approved development authority restoration on 2026-11-10. The owner
subsequently approved development application and the audited two-email recomputation. Both
completed; see the execution evidence below. Production remains outside this authorization.

## Scope and accepted boundary

Restore only the existing two APP and two ORG identifier rotation domains after schema loading
preserved function bodies but omitted their roles, owners and ACLs. Current read-only development
inspection found four canonical functions, eight absent roles, four incorrect function owners and
four PUBLIC execution grants. Audit and APP binding guard bodies/attachments match their original
maintenance-enabled definitions. No source or audit rows need changing during authority restoration.

The two Rails-generated migrations live beside their original owning migrations:

- `db/app_principals_migrate/20261110120346_restore_client_identifier_hmac_authority.rb`
- `db/org_principals_migrate/20261110120505_restore_operator_identifier_hmac_authority.rb`

They reuse the original migration's role-isolation and ownership helpers, without replaying its `up`
method or creating existing tables/functions. Schema metadata shape, role names and audit row shape
remain unchanged. PostgreSQL-specific raw SQL is limited by the accepted ADR amendment: Rails has no
DSL for role ownership and column/function ACLs.

## Acceptance

- AR-1: Validate the complete canonical function and guard bodies, attributes, argument names,
  trigger attachments, required audit sequence, PUBLIC table grants and isolated existing roles
  before enabling authority. Reject unexpected bodies/privileges rather than blessing them with a
  definer owner. Preserve template-carried embedded role identities.
- AR-2: Create only missing isolated NOLOGIN roles; restore original schema USAGE, selected
  source-column SELECT/UPDATE, audit INSERT and sequence USAGE. Transfer each function to only its
  matching definer, revoke PUBLIC execution, and allow EXECUTE only for its matching caller.
- AR-3: Preserve all source and audit rows and function/guard bodies. Each owning database's repair
  is atomic and re-entry is safe. No login membership or schema CREATE privilege remains granted.
- AR-4: Rollback suspends maintenance by revoking caller/PUBLIC EXECUTE and assigning an independent
  executor owner, which the function's embedded check rejects. Preserve roles, restricted grants and
  audit history; reapplication restores operation. Do not restore insecure PUBLIC ACLs.
- AR-5: Verify actual repair, authorized rotation, audit atomicity, rejected direct/peer calls,
  idempotence, safe rollback/reapplication and adversarial drift refusal using ordinary test
  databases with disposable fixtures and transaction rollback. Record observations, not an
  environment-construction test or a new per-run database fleet.
- AR-6: Run scoped Ruby checks and schema-drift verification. Inspect generated dump differences;
  owner/ACL-only repair is not expected to change logical DDL or function bodies. Record unrelated
  baseline drift separately. Do not apply these migrations to development during preparation.

## Risks and recovery

Role/ACL restoration enables narrowly defined authority and therefore requires full-body and
existing-role validation; trusting only an embedded role name could grant privilege to arbitrary
code. Unexpected existing authority is a refusal, not a request to grant more. Five-second lock
waits bound contention. Migrations write no application rows; rollback of a failed database-local
transaction leaves its prior authority unchanged. The two databases are separate transactions; keep
the maintenance window closed if one succeeds and the other fails.

Development apply/rehash instructions belong to the current runbook and the separate
[rehash decision](development-rehash.md). SQL logs and exceptions must not disclose values.

## Preparation results

AR-1 through AR-5 passed isolated actual-migration verification in both ordinary test realms, with
eight refusal partitions each and complete transaction rollback. Both migrations pass syntax and
RuboCop. AR-6 drift verification was executed but reports nine pre-existing ordinary-test/dump
differences; no unrelated dump was changed. No development application or rehash occurred.

Detailed observations:
[preparation evidence](../../evidence/2026-11-10-access-hmac-authority-preparation-R2A9.md).

## Approved development application

Both exact migration versions were applied through the standard database-scoped Rake workflow. Four
dedicated function owners and caller permissions are restored; PUBLIC execution is removed, with no
residual definer schema CREATE. Authority repair preserved Source/audit rows and function bodies.
The separately approved audited rehash then updated exactly two email digests, preserved all
non-digest facts, and added one audit event per realm. Fresh lookups and no-op repeats passed.

[Execution evidence](../../evidence/2026-11-10-access-hmac-approved-execution-K4V8.md). The prior
nine-file schema baseline drift remains a limitation; no unrelated snapshot was replaced.
