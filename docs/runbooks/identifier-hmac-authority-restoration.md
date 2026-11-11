# Identifier HMAC Authority Restoration

## Scope and trigger

Use when the four APP/ORG HMAC rotation functions exist with canonical bodies but schema loading
omitted their original ownership/roles/ACLs. Governing decision:
[identifier HMAC rotation](../../adr/identifier-hmac-emergency-rotation.md). This restores authority
only; it does not recompute identifiers or modify source/audit records. Current preparation and
verification are recorded separately in evidence.

## Prerequisites and approval

The owner must approve application to the target environment, the maintenance window and the
fail-closed rollback described below. Preparation approval is not development application approval.
Stop affected identifier mutations and maintenance callers while inspecting and applying authority.
Use the configured database DDL migration identity, not an application or channel caller identity.
No login memberships or general definer authority are granted by these migrations.

Read the value-free catalog preflight and confirm all four function/guard definitions and trigger
attachments are canonical. Confirm all existing role attributes, memberships, dependencies, ACLs and
object ownership are isolated. Unexpected drift causes refusal; do not remove that check or replay
the original table-creating migrations. Keep credentials/connection secrets out of output.

## Apply after explicit approval only

From the documented container runtime, with the correct target environment and authorized DDL
identity configured, apply the two new migrations using the repository database-scoped workflow. For
development, the proposed commands are:

```sh
RAILS_ENV=development VERSION=20261110120346 bin/rails db:migrate:up:app_zenith
RAILS_ENV=development VERSION=20261110120505 bin/rails db:migrate:up:org_zenith
```

Capture fixed statuses and aggregate counts only. Use null application/SQL logging as in the
prepared maintenance diagnostics; do not retain a raw SQL-bind/exception dump. These commands are
instructions, not an assertion that development application has occurred.

Each migration validates both owned domains first, creates only missing isolated roles, grants only
the original narrow rights, restores owners and removes PUBLIC execution. Function/guard bodies and
trigger attachments are verified but never replaced. Lock waits are limited to five seconds. An
unexpected state or privilege failure aborts that database's transaction.

## Verify before admitting maintenance

- All four functions retain identical canonical bodies, SECURITY DEFINER, argument contracts and
  restricted search paths; their owners match the embedded domain definer.
- Eight roles have restricted original attributes, no unexpected memberships or dependencies, and
  only original narrow privileges. Definers have no residual schema CREATE grant.
- PUBLIC cannot execute the rotation functions; each caller can execute only its own function,
  cannot directly mutate Source/audit records and cannot exercise peer-domain authority.
- All source/audit table rows and sequence state are unchanged by authority restoration.
- Existing binding guards and audit append-only guards remain enabled and unchanged.

Only then request or reuse explicit approval for the separate retained-data rehash procedure. A
successful authority migration alone does not make old lookup digests current.

## Rollback or partial failure

Each database is independent. A failed transaction leaves that database unchanged. If one database
succeeds and the other fails, keep maintenance closed and investigate; do not use the restored
channel to bypass another channel's failure.

The corrective migration's `down` suspends maintenance: it revokes PUBLIC/caller execution and
assigns the functions to an independent migration executor, making the embedded owner check fail. It
preserves audit history and the isolated roles/minimal grants because templates may share
cluster-wide role dependencies. It does not recreate insecure PUBLIC execution or drop data/roles.
Reapply `up` after investigation to restore the accepted authority. Record the rollback/application
versions and verified outcomes without identifiers, digests, credentials or connection URLs.
