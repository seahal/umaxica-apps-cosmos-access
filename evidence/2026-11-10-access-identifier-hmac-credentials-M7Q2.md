# Access identifier HMAC credential migration

Date: 2026-11-10 UTC. Full HEAD: `281a9e5c539bc0b89b4d37ff5bd6f102976ad4c4`. The worktree contains
extensive pre-existing uncommitted changes affecting runtime and tests.
`.env.container.devcontainer` was already modified before this task; its other content was
preserved. No commit was created.

## Authorization and accepted scope

Owner instruction dated 2026-11-10: generate independent Access development/test lookup HMAC keys,
move them into encrypted credentials, remove their environment sources, adapt/test consumers,
prepare a development rehash plan and obtain owner approval before executing it. No other credential
family, old salt, history key, readable-data encryption key, master key or repository was rotated.

Keys in scope:

- `APP_EMAIL_ADDRESS_HMAC_KEY`
- `ORG_EMAIL_ADDRESS_HMAC_KEY`
- `APP_TELEPHONE_NUMBER_HMAC_KEY`
- `ORG_TELEPHONE_NUMBER_HMAC_KEY`

Specification: `specs/access-identifier-hmac-credentials/spec.md`. Decision basis:
`docs/backlog/2026-11-10-secrets-from-credentials-only.md`.

## Source inventory and migration

| Source                                                  | Assignments before | Removed | Remaining |
| ------------------------------------------------------- | -----------------: | ------: | --------: |
| `.env.container.devcontainer`                           |                  4 |       4 |         0 |
| `.env` (local, ignored)                                 |                  4 |       4 |         0 |
| `.github/workflows/ci.yml` (two job environment blocks) |                  8 |       0 |         8 |

Repository source/hidden-file scan and explicit local `.env` inspection located those sources.
Compose and devcontainer Compose files contained no direct assignments of the four names; the
existing loader/source wiring supplies the local environment-file settings. Tests intentionally use
controlled ENV values to prove they cannot substitute for credentials; those are behavioral inputs,
not runtime provisioning sources. Historical prose and test source references were not deleted.

**CI source removal is blocked.** `.github` is a ZFS mount with `ro` options
(`findmnt -T .github/workflows/ci.yml`). Attempting the authorized eight-line removal failed with
`OSError: [Errno 30] Read-only file system`. The workflow file was not changed and the restriction
was not bypassed. A writable checkout/mount is needed to remove only those eight assignments. Old CI
values remain in that source, although the changed lookup implementation ignores them. No raw diff
of secret-bearing environment files was printed.

Used the installed Rails `ActiveSupport::EncryptedConfiguration` API, the same reader/writer used by
Rails credential editing, with the exact development/test paths and existing environment decryption
keys. Plaintext was handled only in process memory. Appended four independently generated
`SecureRandom.hex(32)` entries to each environment. Verified all eight generated values were
distinct and each decrypted configuration equaled its original entries plus only those four
additions. Verified both decryption key files were unchanged. No value, value prefix or fingerprint
is recorded in this task.

| Encrypted file                           | New lookup key entries | Unrelated decrypted entries changed |
| ---------------------------------------- | ---------------------: | ----------------------------------: |
| `config/credentials/development.yml.enc` |                      4 |                                   0 |
| `config/credentials/test.yml.enc`        |                      4 |                                   0 |

## Code and test changes

`IdentifierBlindIndex` now reads `Rails.application.credentials.option(key)` directly and requires a
nonblank String. It retains the existing named `KeyError` for absent/invalid key material. The
explicit ENV fallback was removed. The installed `Rails.app.creds` wrapper itself prioritizes ENV,
so retaining it would violate the accepted credentials-only behavior even without the explicit
fallback. This scoped interpretation is recorded in the specification. Production delivery remains
deferred; production boot is already unconfigured.

`IdentifierHistoryFingerprintVerifier` compares its separate history key against the four live keys
in direct credentials only. The four live-key ENV comparisons were removed. History-key provisioning
itself remains unchanged and out of scope.

Four test files were adapted: `test/lib/identifier_blind_index_test.rb`,
`test/lib/realm_identifier_digest_test.rb`,
`test/lib/identifier_history_fingerprint_verifier_test.rb`, and
`test/services/realm_identifier_hmac_rotation_test.rb`. Coverage includes conflicting and ENV-only
values, missing/nil/empty/whitespace credentials across all four realm/channel keys, realm/channel
separation, history-key isolation and actual digest rotation with controlled credential inputs. No
new literal credential value is used by fixtures or tests. Rotation tests substitute credential
inputs, not the digest behavior being verified. Global test setup and production
validations/associations/triggers were not weakened.

## Verification

First command (`OTEL_SDK_DISABLED=true PARALLEL_WORKERS=2 bin/rails test`) selected:

- `test/lib/identifier_blind_index_test.rb`
- `test/lib/realm_identifier_digest_test.rb`
- `test/lib/identifier_history_fingerprint_verifier_test.rb`
- `test/services/realm_identifier_hmac_rotation_test.rb`
- `test/services/identifier_blind_index_backfill_test.rb`

Result: **57 runs, 491 assertions, 0 failures, 0 errors, 0 skips**, exit 0.

Second command (`OTEL_SDK_DISABLED=true PARALLEL_WORKERS=2 bin/rails test`) selected:

- `test/security`
- `test/services/identifier_hmac_emergency_rotation_test.rb`
- `test/services/identifier_hmac_maintenance_boundary_test.rb`
- `test/integration/email_sign_in_enumeration_parity_test.rb`
- `test/integration/email_sign_in_flow_isolation_test.rb`
- `test/models/client_email_test.rb`
- `test/models/operator_email_test.rb`
- `test/models/client_telephone_test.rb`
- `test/models/operator_telephone_test.rb`

Result: **268 runs, 1406 assertions, 0 failures, 0 errors, 0 skips**, exit 0. Combined: 325 runs,
all passed.

Scoped RuboCop on both changed application Ruby files and the four changed test files: six files, no
offenses, exit 0 after correcting two test formatting offenses. The only later application edit was
an explanatory comment; that file was linted again successfully. Scoped `git diff --check` passed.
No full CI or external service validation was run. CI configuration construction was inspected
directly, not added as an environment-setup test.

## Read-only development preflight

Booted Rails with application/SQL logging directed to the null sink, OpenTelemetry disabled and
PostgreSQL `default_transaction_read_only=on`; scanned decrypted identifiers only in memory.
Explicitly removed the four names from the probe process environment before boot and verified none
reappeared. No rehash operation was invoked.

| Table                 | Rows | Stale digests | Missing digests | Malformed | Decryption failures |
| --------------------- | ---: | ------------: | --------------: | --------: | ------------------: |
| `client_emails`       |    1 |             1 |               0 |         0 |                   0 |
| `operator_emails`     |    1 |             1 |               0 |         0 |                   0 |
| `client_telephones`   |    0 |             0 |               0 |         0 |                   0 |
| `operator_telephones` |    0 |             0 |               0 |         0 |                   0 |

APP email and telephone finalized-binding counts were both zero. `ClientEmail.find_by_address` and
`OperatorEmail.find_by_address` completed without exception. Existing emails did not match their old
digests under the new credentials, as expected before recomputation. No identifier, record ID,
digest or full model attributes left the process.

## Development server verification

Started an isolated Puma development process on loopback, port 3825, then stopped it. Initial HTTP
probes under PostgreSQL read-only mode failed with `PG::ReadOnlySqlTransaction`: the existing Rails
migration-check middleware calls the existing schema-migration initializer, which issues CREATE
TABLE IF NOT EXISTS even when the migration table already exists. No initializer or migration
protection was altered. Repeated the HTTP probes with the normal development database configuration;
the count preflight remained read-only. No migration command, reset or identifier rehash was run.

| Development request on Auth App host | HTTP status |
| ------------------------------------ | ----------: |
| `/health/liveness`                   |         200 |
| `/sign/in`                           |         302 |
| `/sign/in/email/new`                 |         400 |

No exception was observed on the normal-configuration probes. The email-entry 400 is the guarded
response without ceremony prerequisites, not a successful sign-in. Existing-account email
search/sign-in cannot be certified until the retained development digests are recomputed. New
credentials were present with no live-key ENV source in the probe process.

## Rehash plan, approval and blockers

Concrete plan: `specs/access-identifier-hmac-credentials/development-rehash.md`. It includes the two
stale email rows, zero telephone rows, source-decryption checks, a maintenance write freeze,
per-channel commands, ownership/PII/audit preservation, idempotence checks and partial-failure
recovery. `tmp/access-identifier-hmac-maintenance.rb` is a prepared null-logging wrapper around the
existing Rake task; Ruby syntax only was checked. It was not executed.

The requested `IdentifierBlindIndexBackfill.new.call` visits all four models using ordinary
`save!(validate: false)` updates and does not create canonical rotation audit facts. The accepted
`adr/identifier-hmac-emergency-rotation.md` requires the dedicated restricted SECURITY DEFINER path.
No ordinary development saves, trigger bypass, validation relaxation or audit omission was used to
resolve this conflict.

Further read-only catalog inspection found:

| Realm/channel | Function present | Required definer owner valid | Caller permission checks          |
| ------------- | ---------------- | ---------------------------- | --------------------------------- |
| app/email     | yes              | no                           | Not attempted after invalid owner |
| app/telephone | yes              | no                           | Not attempted after invalid owner |
| org/email     | yes              | no                           | Not attempted after invalid owner |
| org/telephone | yes              | no                           | Not attempted after invalid owner |

Thus the canonical task is not currently executable against development: it would reject function
ownership before recalculation. No owner/grant/function/trigger changes were made.
Preparing/restoring maintenance authority is additional schema/security scope and needs an explicit
owner decision; blindly replaying the original migrations would try to create existing audit tables
and is not proposed. The current plan names the original owning migrations and the exact
privilege/ownership surfaces requiring review.

**Development rehash remains unexecuted, as explicitly required by the owner.** No development
database deletion or reset was performed. Approval for any maintenance-authority repair is separate
from approval to run the retained-data recomputation. Application code and test verification are
complete for the four-key credentials boundary; CI source cleanup and development retained-data
completion remain open.

## Acceptance disposition

- AC-1: assignment inventory complete.
- AC-2: eight independent credentials generated and verified; unrelated entries/decryption keys
  preserved.
- AC-3: consumers/local sources complete; CI eight assignments blocked by read-only mount.
- AC-4: targeted tests, security coverage and Ruby style passed.
- AC-5: plan prepared; not executed. Owner approval and restoration of the pre-existing maintenance
  authority are outstanding.
- AC-6: development boot, normal HTTP probes and error-free public email lookup checked; successful
  retained-email lookup remains pending rehash.
