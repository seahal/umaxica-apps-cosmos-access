# Non-Zenith source retirement and historical preference audits

Date: 2026-11-12. HEAD: f84c87b060876a25994e30e9274420d9067f1367. Uncommitted changes affected all results. The user narrowed this work to Access and approved retiring the named non-OP database dependencies; actual database deletion was not performed.

## Dedicated source retirement

Static Ruby AST inventory identified all requested roots and descendants, with zero parse failures. ClientNotificationRecord and OperatorNotificationRecord were concrete models, not abstract roots. Publishing, Avatar, three settings databases and two signal databases owned 300 model classes in 300 files. Search had one abstract root and no concrete descendants. Namespace support files were inventoried separately.

This slice removed 599 clean dedicated artifacts: 301 model/support files, 175 files under seven retired migration directories, seven generated schema snapshots, 67 exact table fixtures and 49 exact-path model tests. It also removed 48 exact-model policy artifacts, 13 exclusive Publishing supports, 19 exclusive Avatar bootstrap/provision/repair supports/tests, and the exclusive notification owner concern. Search separately removed five dedicated artifacts. No model-tree scan was treated as permission to delete retained cross-boundary consumers. Before hashes, ownership lists and absence results are retained in temporary operational inventories.

The Avatar chain was removed only after its last Auth sign-up support caller was retired by its owning agent. Shared Avatar test factories and mixed lifecycle tests were preserved for the parent to reconcile. Chronicle models, schemas, policies and historical audit fixtures were excluded from the bulk source retirement.

## Explicit preference support approval and automatic review

Automatic approval review rejected an initial combined command deleting 14 preference concerns and nine tests: the scope could include shared settings behavior. Nothing executed. The parent surfaced the rejection and obtained new explicit user approval for the exact shared support removal and affected call-site resolution. Only then were those 23 files removed by an exact path patch, with no live runtime consumers; three external references were comments. Pure request-context/actor-snapshot helpers and mixed JWT/context tests were preserved.

Automatic review separately rejected a bulk replacement of three Chronicle class bodies with autocorrection. Nothing executed. A safer surgical patch subsequently removed only the approved deleted-model associations/navigation/defaults/existence queries, added the explicit historical-reference guard, and preserved all unrelated behavior. No broad replacement or unreviewed autocorrection was retried.

## Historical audit boundary

The user explicitly approved code dependency removal in AppPreferenceChronicle, OrgPreferenceChronicle and ComPreferenceChronicle while retaining their physical Chronicle tables and historical rows. Existing actor/subject scalar identity, event/level relationships, generic optional actor relationships, validations and Retainable behavior remain. No Chronicle DDL, trigger or constraint was changed.

New audit writes referring to any retired AppPreference/OrgPreference/ComPreference actor or subject raise ActiveRecord::ReadOnlyRecord. Existing retired audit actor/subject identity cannot be changed, including with save!(validate: false), and changing the type cannot escape the guard because both stored and proposed types are checked. Historical context metadata and legitimate retention updates remain usable; eligible historical rows can still be purged. Unrelated audit subject types remain accepted. The now-exclusive cross-database coordination helpers were removed after an exact caller search.

These are application callback guarantees. Direct SQL/update_all can bypass callbacks; the unchanged PostgreSQL NOT NULL/FK contracts remain separately tested. This slice adds no claim that PostgreSQL itself enforces the new retired-reference immutability policy.

## Observed tests and checks

- Genuine Red: an isolated real-PostgreSQL harness loaded the exact existing model/concern sources with current writer configurations and rollback-only transactions. It failed with expected ReadOnlyRecord versus actual NameError at AppSettingRecord. This was distinct from earlier full-app eager-load failures, which did not count as behavioral Red.
- Source Green after the surgical change: one run, three assertions, zero failures/errors/skips, covering all three actual models.
- Final standard command: `env -u POSTGRESQL_TEST_PREPARE_DATABASES RUBY_DEBUG_ENABLE=0 RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/models/retired_preference_audit_boundary_test.rb test/models/app_preference_chronicle_test.rb test/models/org_preference_chronicle_test.rb`.
- Result: 14 runs, 138 assertions, zero failures/errors/skips. Tests cover preserved history, four actor/subject mutation paths, type-escape refusal, retired actor/subject creation in all three models, unrelated audit acceptance, context/retention updates, eligible purge and the original PostgreSQL subject NOT NULL contract.
- The first standard run had two new-test setup errors from using nonexistent App event ID zero. Setup was corrected to the authoritative CREATE_NEW_PREFERENCE_TOKEN constant; production constraints and assertions were preserved.
- Final RuboCop: six changed Chronicle Ruby files, zero offenses. Scoped git diff --check passed. Dedicated removal absence checks and remaining model Ruby parsing passed.

Coverage instrumentation, whole-suite regression, final DatabaseConsistency and global source-retirement completeness were not verified by this slice. The parent owns shared connection/CI lists, health, identifier inventories, retained OP consumers, mixed tests and overall acceptance. Existing design/history documents were not rewritten.
