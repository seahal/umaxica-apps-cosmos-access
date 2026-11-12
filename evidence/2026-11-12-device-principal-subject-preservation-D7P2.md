# Device-session principal subject preservation

Date: 2026-11-12. HEAD: f84c87b060876a25994e30e9274420d9067f1367. Uncommitted changes affected all results. This record covers only the approved APP/ORG OP device-session `principal_public_id` persistence slice; it does not report the broader database retirement as complete.

## Contract and implementation

The user approved `principal_public_id varchar(255) NOT NULL` on `client_device_sessions` and `operator_device_sessions`, copied exactly from the existing principal public ID before Zenith removal. No invented subject, default, or missing mapping is accepted. Per realm, four generated migrations add the nullable column, import a reviewed CSV, install a NOT VALID presence CHECK, then validate the CHECK and set NOT NULL. The CHECK also refuses empty/whitespace-only subjects. Existing actor numeric IDs and session public IDs are unchanged.

The tracked exporter `scripts/export_device_session_principal_public_ids.rb` reads the current configured OP and Zenith writer connections in read-only transactions. Its exclusive output files have mode 0600. Identity mappings remain in private untracked CSVs; this record and console output contain no mappings. Import reads one immutable byte snapshot, verifies the required SHA256, validates headers, positive numeric IDs, lengths, duplicate device rows, contradictory actor subjects, and exact device/actor ownership coverage before any update. It locks only the local device table during migration and uses bound native PostgreSQL updates to avoid identity values appearing in migration SQL announcements. Import never instantiates application models or connects to Zenith.

## Required order for existing environments

This is a two-phase source rollout. Stage/copy the tracked exporter into the pre-removal deployment or worktree and run it there while its configured writers and actor data still exist. Retain the private exports and verify their hashes separately; only then apply the source-removal revision and its scoped migrations. A fresh post-removal checkout cannot export existing subjects because its Zenith bindings are deliberately absent. Do not restore retired endpoints or guess connection details.

The subsequent root-authority preflight and writer-pause prerequisites are recorded in [root-authority cutover evidence](2026-11-12-root-authority-cutover-preflight-C9E6.md).

Export before removing Zenith configuration or deleting actor data:

```sh
PGOPTIONS='-c default_transaction_read_only=on' RAILS_ENV=test RUBY_DEBUG_ENABLE=0 bundle exec ruby scripts/export_device_session_principal_public_ids.rb app /private/client-device-subjects.csv
PGOPTIONS='-c default_transaction_read_only=on' RAILS_ENV=test RUBY_DEBUG_ENABLE=0 bundle exec ruby scripts/export_device_session_principal_public_ids.rb org /private/operator-device-subjects.csv
```

Set all four variables before the scoped OP migration workflow:

- `CLIENT_DEVICE_SESSION_PRINCIPAL_PUBLIC_IDS_CSV`: the private APP CSV path.
- `CLIENT_DEVICE_SESSION_PRINCIPAL_PUBLIC_IDS_SHA256`: its separately verified lowercase SHA256.
- `OPERATOR_DEVICE_SESSION_PRINCIPAL_PUBLIC_IDS_CSV`: the private ORG CSV path.
- `OPERATOR_DEVICE_SESSION_PRINCIPAL_PUBLIC_IDS_SHA256`: its separately verified lowercase SHA256.

For another environment, use its explicit `RAILS_ENV` and its own exports; test mappings must never populate another environment. Apply only `db:migrate:op_base_app` and `db:migrate:op_base_org` after confirming pending migrations. Fresh empty tables are an explicit import no-op without CSV environment variables. A nonempty table with no export raises; mappings from an earlier environment are not substitutes. Future writers must supply the authoritative subject explicitly. The exporter is a pre-retirement operation, not a runtime dependency or a fallback lookup after retirement.

Recovery: retain the verified private exports and source actor data until migration and subject verification succeed. A failed transactional import leaves no partial backfill. Import `down` deliberately raises `IrreversibleMigration`: deleting copied identity history is not rollback. Before actor removal, stop rollout on a mismatch and correct the authoritative export; after actor removal, restore the verified identity data from the approved backup/export rather than inventing subjects. No production/shared database was changed in this session.

## Observed verification

- Rails generators produced eight migrations in the two OP migration directories.
- Red: a disposable PostgreSQL database with preexisting device rows failed `missing approved subject column` before implementation.
- Green: the disposable PostgreSQL migration harness executed the actual eight migrations with `strong_migrations` loaded. Both realms preserved exact original subjects, rejected six malformed/duplicate/missing/extra/ownership/length export cases atomically, rejected SQL NULL/empty/whitespace/256-character writes, accepted 254 and 255 characters, and replayed the empty-table import without export variables. The scratch database was removed afterward. This is a data-contract migration check, not an environment-construction Minitest test.
- Configured test writer exports contained two sessions per realm. All eight migrations were applied to those two test OP databases using the exact exports. No shared schema dump was edited by this slice.
- Development was inspected read-only: both exports contained zero sessions. Development migrations were not applied.
- `env -u POSTGRESQL_TEST_PREPARE_DATABASES RUBY_DEBUG_ENABLE=0 RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/models/device_session_principal_public_id_test.rb`: 1 run, 34 assertions, zero failures/errors/skips. This durable test bypasses model validations and checks exact stored subjects plus PostgreSQL NULL/blank/length failures in both realms.
- Device fixture subjects copy their actor fixture public IDs verbatim. The earlier fixture NOT NULL failure was resolved without fabricated mappings.
- Initial generator boot failed because the sandbox blocked the development debugger socket; rerunning with `RUBY_DEBUG_ENABLE=0 RAILS_ENV=test` succeeded. Initial standard test commands were blocked before cases by a stale inherited database-prepare list; clearing that inherited variable used the repository's updated verified list.
- Initial Rake-task loading was blocked before database writes by a removed Avatar translation required by its legacy task. The scoped apply used configured writer `MigrationContext`s; the parent subsequently removed that retired Avatar task.

Coverage instrumentation, whole-suite regression, global DatabaseConsistency, production migration, and final schema-dump reconciliation were not run by this slice. The parent coordinates those broader checks. No DB drops outside disposable verification, CI changes, or existing documentation rewrites were performed.
