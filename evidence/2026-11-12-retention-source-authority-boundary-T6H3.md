# Retention after actor-source retirement

Date: 2026-11-12. HEAD: f84c87b060876a25994e30e9274420d9067f1367. Uncommitted changes affected all results. Scope: application retention code and device subject immutability; no retained database DDL or retired database mutation.

## Approved behavior

RetentionPurgeJob now names its 26 surviving OP, Chronicle and Occurrence models directly. It no longer silently drops unresolved class names. Retired actor/avatar/settings/identifier deletion, source-sign-up cleanup/reporting and ClientSecret lifecycle dispatch were removed from this job. Existing source ownership moved out of Access; no alternative actor or hold state was fabricated.

APP root sessions and otherwise locally eligible APP sign-up flows depended on retired secret/hold/audit sources. Without an authoritative Governance replacement, the job locks and reloads the local candidates, rechecks their owning database clock, reports AuthorityUnavailableError and ultimately raises it. It never releases an APP authority stop or deletes its root/flow on the assumption that an unavailable source means no hold. Existing unfinished/uncleaned local flow holds remain intact. Other independent retained model families continue processing before the failure is re-raised.

ORG root authority-stop retention, sign-in flow OIDC references, terminal session-limit child ordering, writer-database clocks, inclusive purge deadlines, bounded batch size 1..500, the existing operational kill switch and Com preference audit exclusion remain. The job performs no actor anonymization or cross-database child cleanup.

ClientDeviceSession and OperatorDeviceSession now mark principal_public_id readonly through ordinary model writes. Lifecycle metadata remains writable. Existing PostgreSQL NOT NULL/nonblank/length constraints remain unchanged; SQL/update_all can bypass model readonly behavior, and this slice adds no database immutability-trigger guarantee.

## Source closure

After exact consumer checks and clean-file verification, removed the now-exclusive signup-report query/test, withdrawal anonymizer/test, four ClientSecret lifecycle/collection/audit jobs and five dedicated job tests, and RetentionCrossDatabaseChildPurge with its dedicated test. No StepUp audit delivery/outbox job was removed. The four ClientSecret jobs had no independent recurring schedule entries. Scheduling configuration remains parent-owned.

Also removed two explicitly approved orphan concerns after zero retained consumer checks: OperatorSecretCredentialKinds, and AuthenticationCredentialInventoryOwner with its dedicated test. No retained kind catalog, OP model or table was recreated or deleted for those orphan definitions.

The original retention job test retained ten applicable cases and their assertions. Fourteen tests exclusively describing retired actor/avatar/passkey/source-report behavior were removed under explicit approval. Historical Com audit preservation now uses the retained scalar Chronicle row without trying to restore a deleted preference model. The existing loop/error aggregation spy and all its original assertions remain; actual PostgreSQL boundary tests separately verify deletion/refusal behavior.

## Observed TDD and verification

- Added four actual PostgreSQL retention boundary cases and an ordinary model-subject reassignment regression before implementation.
- Genuine Red: six runs, 67 assertions, three failures, zero errors/skips. Due APP roots/flows raised the actual retired Client NameError instead of the explicit authority error; persisted principal subject reassignment actually succeeded.
- Initial Green after guards: six runs, 82 assertions, zero failures/errors/skips.
- Final narrow regression: `env -u POSTGRESQL_TEST_PREPARE_DATABASES RUBY_DEBUG_ENABLE=0 RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/jobs/retention_purge_job_test.rb test/jobs/retention_governance_boundary_test.rb test/models/device_session_principal_public_id_test.rb`.
- Final result: 16 runs, 114 assertions, zero failures/errors/skips. This covers local pending/completed flow retention, unchanged held root/flow snapshots, no authority-stop release before unavailable-source refusal, continued independent processing, actual occurrence/Chronicle timestamps immediately below/at/above the boundary, invalid and inclusive batch limits, suspension/catch-up/idempotency, preserved original error aggregation/registry contracts, readonly subject identity, lifecycle updates and direct SQL PostgreSQL constraints.
- Writer clocks in exact boundary tests are bound to instants read from the owning real database; the operation and SQL constraints are exercised against PostgreSQL, not a fake datastore. Stop release is observed through a collaborator spy specifically to prove it is not entered before the refusal.
- Six owned Ruby files passed RuboCop; scoped git diff --check passed. No global suite or coverage instrumentation was run by this slice.

An automatic review rejected combining a temporary read-only cutover diagnostic with a repository test arithmetic correction. Nothing executed. After the parent confirmed existing ownership, the three exact Rational microsecond corrections were applied separately in the authorized retention test file; no assertion was removed or weakened.

APP physical purge remains intentionally blocked until authoritative external source retention eligibility is implemented and approved. This is a visible incomplete integration, not a successful empty-hold lookup. Production/retired data was not deleted, no queue internals or CI configuration were modified, and global DatabaseConsistency remains parent-owned.

After the 16-case run, the flow classification case was strengthened to cover STARTED/IDLE and CANCELLED/PENDING local holds, plus CANCELLED/COMPLETED and COMPLETED/IDLE source-authority refusals. Its isolated rerun passed: one run, ten assertions, zero failures/errors/skips (`tmp/retention-corrected-flow-green.log`). The 16-case count above predates this expanded matrix; the full batch was not rerun after that change.
