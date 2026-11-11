# Access identifier HMAC keys in encrypted credentials

Status: implementing. Acceptance authority: owner instruction, 2026-11-10, scoped to four live
identifier lookup keys. Decision context:
`docs/backlog/2026-11-10-secrets-from-credentials-only.md`.

## Purpose and scope

Give Access independent APP/ORG email/telephone lookup HMAC keys in development and test encrypted
credentials. Remove those four assignments from local environment files and CI. Preserve every other
credential, encryption key, database, identity binding, and unrelated worktree change. Other secret
families, historical documentation and other repositories are outside this change.

The installed Rails `Rails.app.creds` wrapper reads ENV first. Consequently, this scope uses
`Rails.application.credentials.option` directly for these four keys, including history-key isolation
checks. This implements the owner's credentials-only requirement rather than retaining ENV priority
behind the wrapper. Production delivery remains deferred; production boot is already unconfigured.

## Acceptance

- AC-1: Identify all environment assignment sources by path/key name only.
- AC-2: Add four independent `SecureRandom.hex(32)` secrets to each environment, without disclosing
  any values and while preserving all other decrypted entries and existing decryption keys.
- AC-3: Remove the four source assignments; lookup and history isolation use encrypted credentials
  directly. Missing/blank keys fail with a named error; conflicting ENV cannot substitute.
- AC-4: Adapt tests to controlled credential inputs; run identifier/rotation/search tests, Ruby
  style, and `bin/rails test test/security`. No test depends on the new literal secret values.
- AC-5: Prepare a count-only development rehash preflight, executable plan, safeguards and recovery
  conditions using the owner-approved audited maintenance path. Obtain the owner's explicit approval
  before any development rehash. Until approval, only read application rows in read-only
  transactions.
- AC-6: Verify development server boot and that email lookup at the sign-in boundary does not error.
  Existing-row successful lookup under new keys remains unverified until the approved rehash.

## Risks and execution order

Inventory assignment sources, rotate encrypted entries, remove assignments, change consumers/tests,
verify disposable test behavior, then request development rehash approval on the concrete plan.
Rotated keys make old persisted digests stale until recomputation. No dual-key runtime fallback is
introduced. Backfill must preserve ownership/history; current writer limitations and prerequisites
must be inspected and reported before approval. No database reset or commit is permitted.

Keep AC-5 and existing-row AC-6 open while owner approval or execution is pending. Record actual
commands, outcomes, full HEAD and dirty-worktree scope in a value-free evidence file.

## Current disposition

AC-1, AC-2, AC-4, AC-5 and AC-6 are verified locally. The owner approved development application of
both corrective migrations and the audited two-email rehash. Both digests are current, both
existing-email lookups match, repeat maintenance is a no-op, and development server checks pass.
AC-3 remains incomplete because the `.github` mount is read-only and eight CI assignments could not
be removed. Existing schema dump drift is separately recorded; no unrelated dump was changed.

Execution plan: [development rehash](development-rehash.md). Credential boundary evidence:
[record](../../evidence/2026-11-10-access-identifier-hmac-credentials-M7Q2.md). Authority
preparation: [plan](authority-repair.md). Approved application and rehash:
[execution evidence](../../evidence/2026-11-10-access-hmac-approved-execution-K4V8.md). This
specification remains implementing solely for the blocked CI source cleanup; the local
credential/runtime/data transition is complete.
