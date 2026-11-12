# Access non-OP database removal: implementation and verification

Date: 2026-11-12. HEAD: `f84c87b060876a25994e30e9274420d9067f1367`.
The worktree contains pre-existing, concurrent, and earlier database-consistency changes; this is
not evidence for a clean checkout. Removal implementation is in progress under the approvals below.

## Observed scope

The requested ten writer connections have twenty writer/replica bindings in each of development
and test. Production has no bindings in the current YAML. The inheritance inventory identifies
518 model classes/files: publishing 158, avatar 46, settings 90, signals 6, search 1, and Zenith 217.
ClientNotificationRecord and OperatorNotificationRecord are concrete models. Principal and RP
record roots in the requested list inherit Zenith; they are not additional physical databases.

Access-only disposition, including replica bindings where configured:

| Connection | Classification | Basis and action |
| --- | --- | --- |
| publishing | RETIRE | Explicit removal instruction; remove Access schema/model ownership. |
| avatar | RETIRE | Explicit removal instruction; Governance owns avatar data. |
| app_setting | RETIRE | Explicit removal instruction; Governance owns settings. |
| org_setting | RETIRE | Explicit removal instruction; Governance owns settings. |
| com_setting | RETIRE | Explicit removal instruction; Governance owns settings. |
| app_signal | RETIRE | Explicit removal instruction. |
| org_signal | RETIRE | Explicit removal instruction. |
| search | RETIRE | Explicit removal instruction. |
| app_zenith | RETIRE | Explicit removal instruction; retain OP identity evidence, not actor storage. |
| org_zenith | RETIRE | Explicit removal instruction; retain OP identity evidence, not actor storage. |
| storage | RETIRE (leftover Access artifact only) | Owner confirms connection already removed and not an Access DB. |
| op_base_app | KEEP | Surviving APP OP authority; dependency changes and specific schema additions approved. |
| op_base_org | KEEP | Surviving ORG OP authority; dependency changes and specific schema additions approved. |
| chronicle | KEEP | Retained audit history; only specifically approved code dependency changes in removal phase. |
| queue | EXCLUDED | Solid Queue remains outside remediation. |
| primary | PENDING for original audit | Explicitly retained outside removal; exclusion is not proof of future disposition. |
| occurrence | PENDING for original audit | Explicitly retained outside removal; no schema changes authorized here. |
| rp_base_app, rp_core_app, rp_warp_app, rp_palm_app | PENDING for original audit | Explicitly retained outside removal; no schema changes authorized here. |
| rp_base_org, rp_core_org, rp_warp_org, rp_edit_org, rp_tech_org | PENDING for original audit | Explicitly retained outside removal; no schema changes authorized here. |

RETIRE above describes Access connection/schema implementation ownership. It does not assert that
an external physical database was deleted, that Governance data was migrated in this session, or
that a destination repository was changed. No destination was guessed to be KEEP.

Commands used include `git status --short`, `git rev-parse HEAD`, Ruby Ripper superclass inspection,
and `rg` over model constants, connection names, database dumps, and runtime callers. Focused
removal tests have run as recorded below; full acceptance gates remain outstanding. No retired
database has been dropped for this task.

## Out-of-scope boundary and approval

Retained ClientToken, OperatorToken, and both DeviceSession models reference removed actors.
The owner approved OP-side dependency removal, with schema changes requiring separate approval.

Existing refresh reads actor active state and authentication epoch while locking Zenith. Operator
capability checks also read Zenith. Existing subject generation uses the actor's public_id, which
is absent from retained device/root/grant tables. Device public_id identifies the device session,
not the actor, and cannot replace it. Optional logout hints do not provide an authoritative
complete replacement. Replacing these checks with an always-active object is unacceptable.

The owner subsequently approved persisting the existing actor public ID on each realm's device
session, with exact pre-removal backfill and rejection of missing mappings. The owner also approved
implementing signed Governance revocation commands and explicitly refusing capability-dependent
refresh. The concrete JWT request/acknowledgement and two realm-local receipt tables received
separate approval. Implementation is in progress; approval is not verification evidence.

Search's model, dedicated test, schema dump, migration directory, connection bindings, identifier
inventory entry, and runtime preparation list entries have been removed. Scoped RuboCop passed
for the three changed Ruby shared files. The only remaining runtime/configuration `search` hit is
the unrelated i18n-tasks search configuration. Historical document references remain intentional.
GitHub workflow references remain untouched under the no-CI-change boundary; config/ci.rb received
only the explicitly requested database-list deletion. Local inherited preparation environment
variables required `env -u POSTGRESQL_TEST_PREPARE_DATABASES` to reload the updated local list.

Standard Rails test attempts were blocked before test execution by import migration safety checks
while the new migration series was being completed. These are not behavioral Red results. The
device-session owner is verifying the stages with real disposable PostgreSQL databases before
resuming shared tests. Avatar's dedicated obsolete backfill Rake task was deleted; it previously
blocked task loading through a missing translation and depended solely on the removed feature.

## Allowlist and documentation findings

Dedicated ADR decision 6 database/abstract-record allowlists were not located. Existing
primary_database_ownership_test preserves databases now requested for removal, and
database_migration_path_ownership_test preserves search. These require scoped review.

Documents for Claude's review include `adr/access-is-a-pure-openid-provider.md`,
`docs/architecture/database-authority-placement.md`,
`docs/architecture/model-database-inventory.md`, relevant authentication checklists, and the
`docs/mermaid/` inventories. Historical references are not automatically stale specifications.
No existing documentation was rewritten for this removal investigation.

## Current result

The owner's storage addendum confirms that storage is not an Access database. The clean leftover
`db/storage_structure.sql` contained only `ar_internal_metadata` and `schema_migrations`; it was
deleted without modifying a database. Its pre-deletion SHA256 was
`f685d7ae0238315f3694c9df794f5729e1b0a02998f1a478af2645734e55aca0`.
Storage is included in the final connection/class/path grep.
`config/storage.yml`, `db/storage_migrate/`, and storage connection entries are absent. A distinct
plural legacy directory, `db/storages_migrate/`, remains unconfigured and is separately reported;
the addendum did not describe that directory. The Active Storage dependency boundary test remains.

Removal is not complete. Final acceptance grep, reduced development/test db:prepare, complete
fail-closed entry-point coverage, full RuboCop, ERB lint, Brakeman, and the full Rails suite remain
unverified for this task.
Earlier database-consistency work remains preserved and paused pending this higher-priority task.

## Focused verification during implementation

- Signed Governance receiver: final focused batch passed 26 tests / 509 assertions with no
  failures, errors, or skips. Eleven production files measured 351/368 executable lines (95.38%),
  110/126 branches (87.30%), and 40/42 methods (95.24%). This is scoped coverage, not application
  coverage. Real Governance issuer/JWKS URLs remain unknown; missing configuration returns 503.
- Retention boundary: three-file batch passed 16 tests / 114 assertions. The subsequent fixture
  correction and four flow-state partitions passed one test / 10 assertions. Retired source
  authority is refused before destructive retention work; independent local retention continues.
- Canonical OP access-token, UserInfo, and child-revocation behavior passed 14 tests / 219
  assertions. Valid UserInfo credentials explicitly receive unavailable until Governance lookup
  exists; child grant revocation preserves the existing access-JWT lifetime contract.
- A new actual PostgreSQL refresh-reuse test exposed an audit-projection regression: Chronicle
  connection failure propagated from the scalar writer (one test / two assertions / one error),
  risking rollback of the OP stop transaction. Scalar recovery-record handling now passes the
  three-test / 37-assertion audit batch and preserves the authoritative stop on projection failure.
- Existing refresh, typed browser rotation, scalar audit, authenticated-code refusal, and JWT
  claims passed a five-file batch of 16 tests / 150 assertions. Browser cases include wrong-realm
  refusal, rollback on response-signing failure, and device/root/grant revocation on replay.
- Both-realm HTTP logout, browser resolution, and Chronicle halt constraints passed 11 tests /
  208 assertions. Logout first failed with the removed `current_resource` lookup; the final path
  uses real OP roots and preserved scalar actor references, and clears credentials after the stop.
- Retained sign-in/signup/receipt/invitation models passed 20 tests / 107 assertions following an
  actual Red batch (20 tests / 75 assertions, 11 failures and two errors). New Governance-dependent
  progress is explicitly unavailable; historical scalar metadata and local terminal transitions
  remain usable.
- Existing browser/RP refresh, status, expiry and historical-grant contracts passed 59 tests /
  379 assertions. A subsequent grant-only stop boundary case passed one test / 32 assertions;
  it first exposed a real lookup of the physically deleted issuing root. The stop now follows
  Device Session -> current root -> grant, preserving the canonical ownership chain.
- Full `bundle exec erb_lint --lint-all`: 549 files, no ERB errors. Standard Brakeman initially
  failed its mandatory latest-version network lookup in the sandbox; the same command with
  network access scanned successfully and reported one SQL warning in the earlier custom JSON
  validator. Replacing identifier interpolation with quoted Arel expressions retained all eight
  PostgreSQL/model halt tests and the standard Brakeman rerun reported zero security warnings.
- Development `db:prepare` completed after a read-only check found 39 pending migrations, all on
  the three KEEP databases, and zero APP/ORG device sessions and roots. The three KEEP structure
  dumps were generated via Rails. The multi-database dump unexpectedly wrote the primary dump;
  its exact pre-command bytes were restored, and the ORG dump was regenerated with an explicit
  `SCHEMA` path. No primary database schema was changed.
- Development `db:seed` initially failed on removed `PersonaMembershipKind`; after removing
  retired catalogs and sample actor/publishing writers, it completed successfully. Retained
  Chronicle and OP reference catalogs, including both evidence-state catalogs, remain seeded.
- The first full Rails suite stopped during test loading on a removed AuthenticationClient alias;
  it did not run the full suite. Remaining retired-code and test references need further cleanup.
- A subsequent full-suite load exposed an obsolete AuthenticationOperator harness in the emergency
  continuity test. Its surviving standby-refresh invariant now uses real OP fixtures and three
  rotations; the focused test passed 2 tests / 12 assertions. The next full-suite attempt stopped
  during loading on a removed `ClientEmail` constant in the signup OTP concurrency suite. No
  full-suite pass is claimed.
- The signup OTP issuer concurrency suite tested exclusively the retired email/telephone signup
  issuer and was removed with that feature. The next full-suite attempt stopped while loading the
  retired authentication controller reference in `credential_timing_protection_contract_test.rb`;
  further classification and cleanup are required.
- Removed the retired credential-controller cases from that mixed timing suite while preserving
  its Entra strategy lookup assertion. Explicitly loading the still-present strategy made the
  retained test pass (1 test / 4 assertions). The next full-suite load stopped on a removed
  `Auth::Org::Sign` controller in `mfa_challenge_absence_test.rb`.
- The MFA route-absence test was retained under an existing test namespace and now uses the
  required configured host; all 5 cases passed. The next full-suite load stopped on the removed
  controller namespace in `test/controllers/auth/org/in/secrets_controller_test.rb`.
- The legacy secret route refusal test was retained under an existing namespace and passed
  1 test / 2 assertions. The next full-suite load stopped on a deleted AuthenticationClient
  concern in `test/controllers/concerns/auth/client_test.rb`.
- Removed three tests dedicated to the deleted AuthenticationClient/AuthenticationOperator
  concerns. The next full-suite load stopped at another old AuthenticationOperator harness in
  `authentication_operator_redirect_host_test.rb`; the suite has not yet executed in full.
- The latter contained only the retired actor-backed failed-login audit path and was removed.
  The next full-suite load stopped on the removed `PasskeySignInFlow` concern in its old
  dedicated refusal test; no full-suite success is claimed.
- Removed the dedicated `PasskeySignInFlow` test after confirming all its cases exercised that
  retired concern. The next full-suite load stopped at the removed `VerificationBase` concern
  in `verification/base_rt_issuer_test.rb`.
- The latter test exercised only the removed cookie-backed verification concern and was removed.
  The next full-suite load stopped at an obsolete Auth application-controller reference in
  `controller_base_inheritance_test.rb`; its surviving inheritance guards still require review.
- Removed only the retired Auth application-controller entries from the mixed inheritance guard;
  the retained 7 tests / 29 assertions passed. The next full-suite load stopped on a removed
  `ClientEmail` reference in `contact_email_signup_source_audit_test.rb`.
- The source-audit integration suite exercised only the retired email signup and its removed
  identity/contact databases, so it was removed with that feature. The next full-suite load
  stopped on an obsolete Auth controller reference in `erb_layout_preference_controls_test.rb`;
  retained layout assertions require classification before any edits.
- The layout test contained only removed Auth preference-control endpoints and layouts, so it
  was removed with those features. The next full-suite load stopped on a deleted `AppPreference`
  reference in `preference_browser_api_contract_test.rb`; no suite-wide success is claimed.
- The browser API suite exclusively exercised removed preference endpoints and was removed with
  them. The next full-suite load stopped on a deleted `Client` reference in
  `signup_otp_delayed_transport_test.rb`.
- The delayed transport suite covered only retired signup OTP delivery and was removed. The next
  full-suite load stopped because `processor_erasure_delivery_contract_rollback_test.rb` requires
  a migration from the deleted app principal migration directory; its ownership remains to review.
- That rollback test exclusively exercised the removed principal migration and was removed. The
  next full-suite load stopped at an old `Operator` reference in `has_birthdate_test.rb`.
- `HasBirthdate` had no application consumers after retirement; its sole test and concern were
  removed. The next full-suite load stopped on a removed `ClientEmail` in
  `contact_binding_constraints_test.rb`.
- The contact binding constraint test covered only the removed client email and telephone
  tables and was removed with those tables. The next full-suite load stopped on `Client` in
  `credential_registration_otp_proof_database_test.rb`; that mixed ownership needs review.
- The OTP proof test also exercises direct-write invariants on retained OP ceremony tables; it
  has not been deleted. Its setup still relies on the removed credential owner and must be
  reconstructed from valid OP-owned data before those assertions can run.
- Current standard `RAILS_ENV=test bundle exec database_consistency` exited 1 with 127 checker
  findings across all loaded models. This is an overall count, not a KEEP-only or Solid Queue
  count. The results have not yet been attributed to their database owners, so no KEEP-zero
  conclusion is supported. Two findings concern the explicitly approved historical root
  associations on OpAppGrant and OpOrgGrant; their lifecycle contract needs separate analysis.
- Four retained OP audit-attempt models now validate per-outbox attempt number and the existing
  partial unique delivery rule. Before the change a duplicate ordinary save raised PostgreSQL
  `RecordNotUnique` (2 tests / 38 assertions / 1 error); afterward the same actual PostgreSQL
  contract suite passed 2 tests / 116 assertions, including direct-write constraint checks.
- Scoped RuboCop passed on all four audit-attempt models and their test. Re-running the standard
  DatabaseConsistency command reduced overall findings from 127 to 119: eight previous
  findings disappeared and no new findings appeared. The 119 are not yet re-attributed by DB.
- Attribution of that same run used each reported model's actual Rails connection configuration:
  OP APP 55, OP ORG 38, Chronicle 1 (KEEP total 94); nine RP connections total 33 (pending/out
  of scope); Solid Queue 0. All 127 names resolved. This attribution classifies findings; it
  does not exclude any model or checker from the original execution.
- The subsequent 119-finding run attributed 51 to OP APP, 34 to OP ORG, 1 to Chronicle
  (KEEP total 86), 33 to RP connections, and 0 to Solid Queue. After that measurement,
  ClientChronicle gained validation matching its existing unique event UUID index while retaining
  historical UUID-less rows. The focused test first failed because a duplicate was valid; after
  the change the four-test / 43-assertion audit suite passed, including direct PostgreSQL
  duplicate enforcement. Checker counts have not yet been refreshed for this last change.
- After the Chronicle change, the standard DatabaseConsistency run reported 118 total findings,
  down from 119: the ClientChronicle UUID finding disappeared and no new finding appeared.
  The affected model and audit test passed scoped RuboCop. KEEP attribution from the preceding
  run was 86, so the removed Chronicle finding accounts for one; a fresh full attribution is
  still required before a final count.
- Both OP step-up ceremony models now validate the existing unique result digest index. The
  verified-ceremony duplicate test was Red first; the new contract and transition regressions
  then passed 48 tests / 310 assertions, including PostgreSQL validation-bypass checks. The
  DatabaseConsistency result has not yet been refreshed after this change.
- Both retained email ceremony models now validate EVP nonce and token digest uniqueness where
  present, matching their existing partial indexes. The test was Red because duplicate errors
  were absent; actual PostgreSQL validation-bypass checks then passed 1 test / 12 assertions.
  Error attribute labels were added to both locale bundles; checker counts require a rerun.
- The subsequent DatabaseConsistency run reported 92 total findings, down from 96: four EVP
  digest index findings disappeared with no new finding. Scoped RuboCop passed the two email
  ceremony models and their test. Final attribution and full verification remain outstanding.
- Both retained sign-in flow models now validate their existing unique result-digest indexes.
  After correcting the test fixture to satisfy the authentication evidence CHECK, duplicate
  validation was Red; the new direct PostgreSQL test and existing flow regressions then passed
  7 tests / 50 assertions. The checker has not yet been rerun for this change.
- The subsequent DatabaseConsistency run reported 90 total findings, down from 92: both sign-in
  result-digest index findings disappeared and none appeared. Scoped RuboCop passed the two
  models and their test. Final DB attribution and complete verification remain outstanding.
- Operator signup history now validates its existing unique result-digest index. The new duplicate
  test failed before the change; it and both-realm sign-in result checks passed 2 tests / 9
  assertions afterward, including direct PostgreSQL rejection. Client signup still needs its
  admission-binding setup and independent verification; checker counts need a fresh run.
- The following DatabaseConsistency run reported 89 total findings, down from 90: the ORG signup
  result-digest finding disappeared and none appeared. Scoped RuboCop passed its model and test.
  Final attribution, APP signup verification and whole-project completion checks remain.
- The 89-finding run was attributed by actual model connection: OP APP 37 and OP ORG 19
  (KEEP total 56), nine RP connections 33, Chronicle 0 and Solid Queue 0; every reported model
  resolved. No checker or connection was excluded. These figures are an intermediate result,
  not a completed whole-project audit.
- Both audit delivery reference states now declare their sensitive-admission outbox dependents
  with restrictive deletion, matching the existing PostgreSQL foreign keys. Before the change,
  destroy reached a database foreign-key error; after adding both locale labels, ORM restriction
  and direct SQL refusal passed together with uniqueness checks: 2 tests / 22 assertions.
  DatabaseConsistency needs another run.
- A ClientSignInFlow now declares restrictive historical receipt dependents matching its existing
  foreign key. The new direct-SQL history test first produced an ORM foreign-key exception;
  after adding the relation it also exposed an inverse-autosave regression in the existing
  Governance-unavailable tests. Disabling that association inverse preserves the refusal and
  allows later flow updates; both receipt and flow suites passed 10 tests / 44 assertions.
  ORM and direct SQL deletion refusal are tested. Checker counts require a new run.
- The subsequent DatabaseConsistency run reported 82 total findings, down from 83: the receipt
  dependent finding disappeared and none appeared. Scoped RuboCop passed all three affected
  files. Final database attribution and whole-project verification remain outstanding.
- The subsequent DatabaseConsistency run reported 83 total findings, down from 85: the two
  sensitive audit delivery-state dependent findings disappeared with no new findings. Scoped
  RuboCop passed all five affected files. Final attribution and full verification remain.
- The two device session and two OIDC connection models now validate their retained non-null
  owner scalar IDs after removal of external actor associations. The test first failed for a
  missing model error; after the change, model checks and real PostgreSQL null rejection passed
  1 test / 8 assertions. Checker counts require a new run.
- The following DatabaseConsistency run reported 85 total findings, down from 89: the four
  owner-ID null-validation findings disappeared and none appeared. Scoped RuboCop passed all
  five affected files; after adjusting the assertion for lint, the focused test passed again
  with 1 test / 12 assertions. Full attribution and whole-project verification remain.
- Regenerated the tracked database_consistency patch to include both the explicit RESTRICT and
  JSONB uniqueness checker corrections and their specs. It applied cleanly to an isolated archive
  of the recorded fork HEAD; all six changed files matched the tested local fork byte-for-byte.
- The subsequent DatabaseConsistency run reported 96 total findings, down from 98: the two
  step-up result digest index findings disappeared, with no new finding. Scoped RuboCop passed
  the two models and their test. DB attribution and full completion checks remain outstanding.
- Both OP step-up audit outboxes now validate event UUID uniqueness and the existing conditional
  rejected-attempt identity. The new actual PostgreSQL test first failed on a duplicate accepted
  by validation; after the change it and the existing suites passed 9 tests / 48 assertions.
  Existing native-index assertions continue to bypass validation and check `RecordNotUnique`.
  Scoped RuboCop passed after formatting. Checker counts remain to be refreshed.
- The next DatabaseConsistency run reported 114 total findings, down from 118; the four step-up
  outbox unique-index findings disappeared and no new finding appeared. The related final test
  batch passed 9 tests / 50 assertions, including the translated validation failure and direct
  database bypass. These counts precede final whole-project attribution and verification.
- Both sensitive-admission audit outboxes now validate the existing independent unique event UUID
  and context-reference indexes. The new test first failed because validation accepted a
  duplicate; after fixing an initially inconsistent test payload, native PostgreSQL bypass and
  related audit-attempt tests passed 3 tests / 128 assertions. Checker counts require rerun.
- The subsequent standard checker run reported 110 total findings, down from 114: four sensitive
  audit-outbox index findings disappeared and none appeared. Scoped RuboCop passed all three
  affected files. DB-level final attribution and the full suite remain outstanding.
- Client and operator sensitive admissions now validate their existing unique public reference
  and secret digest indexes. The PostgreSQL test first failed because a duplicate was valid;
  after the fix, both model and validation-bypass checks passed 2 tests / 24 assertions.
  The checker must be rerun to measure its current findings.
- The subsequent checker run reported 106 total findings, down from 110: four sensitive
  admission unique-index findings were resolved and no new finding appeared. Scoped RuboCop
  passed the two models and their test. Final DB attribution and complete verification remain.
- Both OP step-up ceremony models now validate their existing unique cancellation reference and
  digest indexes while allowing an absent handoff. The new test was Red on duplicate validation;
  afterward it and the retained evidence-state contract suite passed 7 tests / 174 assertions,
  including actual PostgreSQL bypass attempts. Checker counts need another run.
- The subsequent DatabaseConsistency run reported 102 total findings, down from 106: four
  cancellation-handoff index findings disappeared with no new findings. Scoped RuboCop passed
  the two ceremony models and their test. Final DB attribution and full verification remain.
- Both OP OIDC authorization transaction models now validate the existing cancellation handoff
  reference and digest unique indexes. Duplicate validation was Red before the change; the new
  real PostgreSQL contract and the step-up counterpart passed 2 tests / 24 assertions afterward.
  Native bypass still raises `RecordNotUnique`; checker counts require a fresh run.
- The next standard DatabaseConsistency run reported 98 total findings, down from 102: all four
  OIDC handoff index findings disappeared and none appeared. Scoped RuboCop passed the affected
  models and test; full suite, final attribution and reconstruction remain outstanding.

- Replaced deleted Zenith actor/contact setup in the retained credential-registration OTP database
  test with the existing OP ceremony operations. The full-suite load previously failed on the
  removed `Client` constant; the adapted PostgreSQL test passed 4 tests / 240 assertions with
  its malformed-write, receipt boundary and terminal immutability checks retained. Scoped
  RuboCop corrected formatting and passed. Deleted the exclusively retired email model and
  enforcement effect/case public-ID tests. A subsequent full-suite attempt still stopped at
  `test/models/enforcement_record_uniqueness_test.rb`, which references the removed
  `AppEnforcementCase`; the full suite has not run to completion.
- Classified all 82 findings in `tmp/non-op-database-consistency-after-receipt.log` against
  the actual model connections: 33 `op_base_app` and 16 `op_base_org` (49 KEEP total), and
  33 RP findings outside the current scope. There were no unclassified findings or queue
  findings in that run. These are outstanding findings, not a clean result.

- Historical secret sign-in receipts now validate the three independent unique identifiers
  already enforced by PostgreSQL. The new test was Red on the first duplicate, and the receipt
  suite passed 8 tests / 31 assertions after the change. It exercises both model validation and
  `insert_all!` bypass. After formatting, the combined receipt, logout public-ID constraint and
  revocation receipt ordering tests passed 11 tests / 40 assertions. A parallel attempt encountered
  the test database process lock and did not run; the successful combined run was serialized.
- Both Governance revocation receipt models now order implicitly by recorded `committed_at`, with
  UUID as a stable tie-breaker. Two tests first failed under UUID-only ordering; the operation and
  ordering batch passed 9 tests / 170 assertions. Recorded time is not a guarantee of PostgreSQL
  transaction commit order. The standard checker reported 77 total findings, down from 82: three
  receipt uniqueness and two receipt ordering findings disappeared. Other findings remain.
- Removed seven unused services for retired Zenith actor and credential features, and removed the
  processor-erasure notification jobs, receipt consumer and only their two recurring schedule
  entries. The existing unavailable entry-point and sign-in-flow batch passed 9 tests / 118
  assertions. Historical descriptions were not rewritten. Retired-only tests were removed, while
  the `logout_transactions` identity length assertion in the mixed capacity test was retained.
- Repeated full-suite loading advanced to `test/models/session_limit_resolution_uniqueness_test.rb`,
  which still requires deleted `Client` and `Operator` actor models and also asserts retained OP
  uniqueness and lifecycle contracts. It has not been deleted or weakened; the full suite still
  does not run to completion. Other current runtime references and migration verification remain.

- The session-limit issuance entry point now explicitly raises `GovernanceLookupUnavailableError`
  instead of resolving removed actor constants. The two realm tests first failed with `NameError`,
  then passed with the retained partial-index, elapsed waiting-slot and terminal-history checks:
  6 tests / 52 assertions. The full-suite load subsequently advanced to
  `test/models/sign_in_token_uniqueness_test.rb`, which still references removed `Client`.
- Existing `ClientEmergencySignInOperation` unique indexes for operation, credential and root
  token now also have model validations. A new PostgreSQL test failed before the change and then
  passed 1 test / 11 assertions, including `insert_all!` bypass. Scoped RuboCop passed. The
  standard DatabaseConsistency run still exits 1 with 74 total findings; these three findings
  disappeared. RP findings are outside scope and KEEP is not yet clean.
- Removed three further unused Zenith-only services (`SignInOtpResendState`,
  `SignInSelectorParticipant`, `OrgEntraSignInPreflight`) and the obsolete in-code preflight
  comment. Their remaining dedicated and mixed test references still require assessment.

- Session-limit resolution selection, cancellation, expiry and finalization now refuse explicitly
  when Governance authority is unavailable; persisted history is not changed. Eleven branches
  were Red due to deleted actor references or missing actors before the change. The affected
  resolution and sign-in-token database contract suites passed 23 tests / 107 assertions after it,
  including partial unique indexes, persisted facts and the unavailable paths. Their current
  records remain subject to later Governance integration; this does not implement that integration.
- `SecurityOneTimeReveal` validates the pre-existing unique `jti_digest`. Its new duplicate test
  was Red before the change; the related consumption and concurrency tests passed 8 tests / 25
  assertions, including direct PostgreSQL bypass. Scoped RuboCop passed. The standard checker
  remains exit 1 with 73 findings: actual model connection attribution is 25 `op_base_app`,
  15 `op_base_org` (40 KEEP), and 33 RP; none unclassified or queue. Full-suite loading advanced
  to `test/models/signup_otp_proof_database_test.rb`, which still references removed `Client`.

- The signup OTP proof database test now sets up retained ceremony records without removed actors
  or contacts. All existing malformed direct-write and committed-proof immutability assertions
  remain; PostgreSQL passed 2 tests / 58 assertions and scoped RuboCop passed. The next full-suite
  load stopped at `test/models/step_up_transaction_reference_uniqueness_test.rb` on removed `Client`.

- `bin/rails zeitwerk:check` passed in test mode. A full `bin/rubocop` run inspected 2,557
  files and failed with 53 offenses; the run overlapped ongoing test-file edits, so it is an
  intermediate result. Six offenses in affected session/refresh tests were subsequently
  corrected; full RuboCop has not yet been rerun. Some reported empty classes and remaining
  formatting may result from removed features and require individual review.
- Step-up transaction reference uniqueness tests now use retained OP records without removed
  actors. Their PostgreSQL batch passed 6 tests / 38 assertions, retaining direct-write,
  NULL, update and query-budget checks. The full suite requires another run after this change.
- Removed unused Zenith-only `SignRecoveryPasscodeRequirement` and
  `SignAppInEmailAuthenticationState`; their remaining test references need individual review.

- `bundle exec erb_lint --lint-all` succeeded on 542 ERB files; parser emitted a Ruby-version
  compatibility warning. The full RuboCop output includes files with no worktree diff, including
  `test/services/branch_coverage_batch3_services_test.rb`; their baseline status relative to the
  current lint configuration has not yet been established.

- `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error` completed with zero errors
  and zero security warnings on this intermediate worktree. Further changes require reassessment.

- `ClientSignUpFlow` now validates its existing unique result digest while allowing NULL. A
  duplicate test failed before the change; the focused and related digest batch passed 3 tests /
  14 assertions, including direct SQL and NULL coexistence. Scoped RuboCop passed and standard
  DatabaseConsistency returned exit 1 with 72 total findings, one fewer than before. The separate
  existing `operator_sign_up_flow_test.rb` batch produced one `GovernanceLookupUnavailableError`;
  its old successful-registration expectation requires review rather than a success claim.
- The following full-suite loading attempt stopped at `test/models/withdrawal_flow_test.rb`
  on removed `ClientWithdrawalFlow`; no whole-suite result exists yet.

- Removed the unreachable actor-owned session-limit transition and audit implementation behind
  the explicit Governance-unavailable boundary; the retained waiting-slot validation remains.
  The focused regression passed 17 tests / 73 assertions. Updated the operator sign-up test to
  check all eight unavailable transitions and unchanged persisted facts while retaining its
  cancel, retention and state checks: 6 tests / 54 assertions passed. Scoped RuboCop passed.
- Removed the retired Zenith-only withdrawal-flow test. The latest full-suite load stopped at
  `test/operations/dead_identifier_purge_test.rb` on removed `ClientEmail`. The older mixed
  `session_limit_resolution_transactionable_test.rb` also needs adaptation; its retained direct
  PostgreSQL waiting-slot checks must not be removed.

- APP and ORG admission bindings validate their existing conditional unique confirmation
  references. The PostgreSQL contract and existing binding suite passed 14 tests / 254 assertions,
  including repeated NULL, direct-write duplicates, unchanged records and translated errors in
  English and Japanese. Preflight collision now raises `RecordInvalid`, while concurrent database
  collisions still raise `RecordNotUnique`; both refuse the write. Scoped RuboCop passed. Standard
  DatabaseConsistency reports 70 findings (exit 1), with these two findings removed.
- Removed the exclusively Zenith identifier purge operations and their dedicated tests, as well as
  a retired withdrawal test. Full-suite loading advanced to
  `test/operations/email_sign_up_candidate_creator_test.rb` on removed `Client`; the whole suite
  is still incomplete. Runtime reference inventory still includes removed record classes and
  needs continued cleanup.

- Removed six orphaned Zenith-only secret credential operations and both old signup contact
  candidate creators. The corresponding dedicated and mixed test references still need review.
  Removed the retired signup contact candidate and delivery guard tests after checking that
  retained ceremony delivery tests exist separately. The latest full-suite load stopped at
  `test/operations/sign_up_otp_delivery_issuer_test.rb` on deleted `Client`.

- Both Visa sensitive-admission models now validate the three existing independent unique parent
  references. The focused PostgreSQL test was Red before the change and passed 2 tests / 34
  assertions afterward, covering each duplicate through validation and direct writes plus both
  locales. An initially misplaced locale entry caused a YAML load error and was corrected before
  the successful rerun. Checker and lint results are being collected.
- Removed four more orphaned Zenith-only secret operations and the retired signup OTP issuer
  test. Remaining mixed tests and references still require assessment.

- The standard DatabaseConsistency run after the Visa sensitive-admission changes returned
  exit 1 with 64 findings; six previously reported parent-uniqueness findings disappeared.
  Scoped RuboCop passed. A subsequent whole-suite load stopped at
  `test/operations/sign_up_otp_resend_deadline_test.rb` on deleted `ClientEmail`.

- Preserved signup OTP resend deadline coverage using the retained ceremony reissue interface;
  6 tests / 14 assertions passed on PostgreSQL, including values immediately before, at and
  after the deadline and unchanged rejected evidence. Scoped RuboCop passed. The following
  full-suite load stopped in `test/policies/authentication/access_policy_test.rb` at a removed
  policy context.
- Signup termination / artifact cleanup still depend on deleted Zenith actors and credentials.
  Their historical cleanup state and audit must not be marked completed without authoritative
  Governance evidence. The active ADR does not settle treatment of interrupted signups; safe
  explicit failure and a contract for later cleanup remain under investigation.

- `ClientVisaSocialLinkAdmission` validates its four existing independently unique parent
  references. Red preceded the change; the related social and sensitive-admission batch passed
  3 tests / 56 assertions, covering SQL bypass and translated duplicate errors. Scoped RuboCop
  passed; the standard checker remained exit 1 at 60 findings, with four social findings removed.

- Read-only model-connection attribution of the 60 checker findings gives `op_base_app` 16,
  `op_base_org` 11 (KEEP 27), RP 33, queue 0 and unclassified 0. This remains a failing
  checker run, not a zero-warning result.
- Removed the unused old `Authentication::AccessPolicy` with its deleted context and dedicated
  tests. The security inventory keeps its assertions for all remaining policy classes; only the
  deleted policy's record construction branch was removed. The guard still requires execution.

- Signup termination and artifact cleanup now explicitly refuse before any mutation when
  Governance authority is unavailable, replacing removed Zenith-dependent implementation. The
  new boundary test was Red on `ClientSecretIssuance` NameError; with the existing expiry job
  regression, 7 tests / 36 assertions passed, preserving flow attributes and Chronicle counts.
  Scoped RuboCop passed. This does not decide how existing interrupted signups are ultimately
  reconciled with Governance and does not mark cleanup completed.

- The remaining-policy authentication-context inventory ran 3 tests / 625 assertions with
  one error: `ClientEmailPolicy#create?` references removed `Client`. The guard was not disabled
  or weakened; remaining retired policies are being inventoried. The next full-suite load also
  stopped at `test/policies/contact_registration_requirement_test.rb` on removed `Client`.

- `SecurityConsumedJti` now validates the existing purpose/issuer/digest unique key. The new
  tests were Red before the change and 6 tests / 18 assertions passed afterward, covering
  validation and direct-SQL replay rejection, scope separation, writer role and propagation of
  unrelated validation failures. Scoped RuboCop passed; standard DatabaseConsistency returned
  exit 1 with 59 findings, one fewer than before.
- Retired credential, preference and contact policies and their unreachable contact-only operations
  were removed after runtime caller inspection. The remaining-policy security inventory previously
  errored on one such policy and must be rerun; the full suite last stopped at the retired
  `ClientPasskeyPolicy` reference in `test/policies/credential_relation_scope_test.rb`.

- APP/ORG grants validate their existing conditional unique device/client key for unrevoked rows.
  Red preceded implementation; the focused PostgreSQL and refresh regression passed 2 tests /
  42 assertions, covering direct SQL, a distinct client, revoked history, reissuance and
  translated errors. An intermediate test setup omitted required timestamps and was corrected
  before the passing run. No index or database schema was changed; checker/lint are pending.
- The security inventory's next error came from old actor-based OIDC connection listing/unlink
  policies, whose controllers and routes no longer exist. Those two unused policies and their
  dedicated tests were removed; the inventory must be rerun against remaining policies.

- Grant validation and test files passed scoped RuboCop. Standard DatabaseConsistency returned
  exit 1 with 57 total findings, down by the two active grant index findings. Remaining findings
  have not all been addressed. Cookie invariant tests preserve the active host-only, Secure,
  HttpOnly, SameSite and path assertions after removal of preference-only checks; the combined
  inventory run had one error in a now-removed unused policy and needs another execution.

- APP/ORG grant associations now explicitly refuse destruction while step-up context or commit
  history refers to them, matching the existing PostgreSQL foreign keys without adding cascade.
  After correcting a strict-loading test setup, Red showed the native FK rejection; the related
  PostgreSQL and grant uniqueness batch passed 5 tests / 72 assertions, including ORM refusal,
  direct delete refusal, history preservation and both locales. Lint/checker are being collected.
- Removed four further orphaned Zenith Secret operations/queries and the old actor-specific
  credential policy after confirming no remaining runtime callers. The policy inventory still
  requires a rerun after this removal.

- The step-up grant history change passed scoped RuboCop and reduced the standard checker to
  53 total findings (exit 1); its four missing-dependent findings disappeared. A later security
  inventory run passed the cookie guard but still errored on the now-removed retired actor-based
  token policy; the inventory must be rerun after that policy removal. Retained OTP resend tests
  passed 4 cases in the same run, although the combined run had the inventory error.

- Client root-token destruction now explicitly respects historical emergency-sign-in evidence,
  matching the existing restrictive FK. Red exposed the native FK rejection; focused PostgreSQL
  and uniqueness regressions passed 2 tests / 23 assertions, covering ORM and direct SQL refusal
  without deleting evidence. Checker and lint results are pending.
- Removed the unused Zenith TOTP rename operation, its actor-specific policy and dedicated tests.
  Before this removal, the policy inventory had 1 error on that deleted actor reference; it must
  be rerun. OTP resend tests retained their live ceremony assertions (4 passed), although their
  combined inventory batch failed on that policy.

- ClientToken's historical emergency-evidence deletion restriction passed scoped RuboCop and
  the standard checker now reports 52 total findings (exit 1), one fewer than before. The latest
  policy inventory was still failing on retired actor-based capability policies. After confirming
  no production callers, those policies and their dedicated tests were removed; the inventory
  remains to be rerun. Capability-dependent refresh remains explicitly unavailable.

- Auth admission active-parent/purpose uniqueness was investigated but the proposed normal
  model validation was reverted: existing public contract tests explicitly expect PostgreSQL
  `RecordNotUnique` for duplicate `create!` and validated save, whereas the validator changes
  this to `RecordInvalid`. The coordinator regression suite also still references removed actor
  fixtures. Its warnings remain unresolved; tests were not weakened to conceal the conflict.

- `TurnstileReplay` also has an existing duplicate `RecordNotUnique` public contract; a normal
  model validator would alter that error. The warning remains pending a contract-preserving
  solution. Step-up context/transition and audit-outbox/attempt findings involve existing
  `ON DELETE CASCADE` versus ORM restriction; the step-up purge contract explicitly describes
  the database cascade, so neither deletion behavior was changed merely to silence warnings.
- Removed the orphaned Zenith processor-erasure recovery operation, its actor-specific policy,
  and the dedicated notification delivery test. The preceding inventory run failed on that
  policy; it needs another run. The retained OTP ceremony batch passed 7 cases before that
  combined inventory error.

- The active DatabaseConsistency remediation cycle C33 requires passkey challenge-reference
  collisions to remain database-authoritative and retries only the named PostgreSQL constraint.
  A normal uniqueness validator would change the existing `RecordNotUnique` exhaustion contract
  to `RecordInvalid`, so both StepUpSession findings remain unresolved rather than changing that
  contract for the checker.

- The retained OTP committed-retry and authentication-context policy inventory batch passed
  5 tests / 945 assertions with no errors after retired policies were removed. The full suite
  subsequently loaded and began running; it has already emitted at least one old signup actor
  error, so a clean result cannot be claimed. The process remains running at this observation.

- The standard full Rails test command completed: **8,158 runs / 33,868 assertions / 200
  failures / 2,934 errors / 0 skips** (`tmp/retired-tests-full-suite-latest.log`). This is a
  failure, not acceptance. Interim classification found many deleted actor/fixture references and
  old successful-signup assumptions, alongside mixed tests of retained OP refresh, token and
  session-limit invariants. Those mixed checks must be preserved and each failure assessed.
- The separate retained committed OTP and authentication-context inventory batch passed 5 tests /
  945 assertions with no failures or errors; that focused success does not cover the full suite.

- The unchanged passkey reference collision contract was exercised on PostgreSQL for both
  realms: 2 tests / 16 assertions passed, covering named unique-index retries, exhaustion,
  rollback and preserving an existing reference. Scoped RuboCop passed. The two corresponding
  checker findings remain because the accepted contract requires DB-authoritative collisions.
- Removed additional actor/credential/status policies and dedicated tests after checking their
  runtime callers; shared authentication policies and security guards were retained. Tests and
  inventory need rerunning after these later changes.

- After the full-suite failure, six tests were individually identified as dedicated to retired
  preference, Zenith contact or actor withdrawal models and removed. Tests mixing OP token,
  ceremony, Chronicle or authentication boundaries were retained for adaptation. These deletions
  postdate the recorded full-suite run; the full suite has not been rerun afterward.

- `OperatorTokenTest` now prepares retained OP device sessions and stored subject snapshots
  instead of removed Operator records. The earlier full run had 36 actor-dependent errors; the
  adapted suite passed 33 tests / 114 assertions, retaining token FK, rotation and retention
  checks. Three tests solely about the removed actor association or actor deletion were removed.
  Scoped RuboCop passed. The APP counterpart is still being adapted.

- `ClientTokenTest` was Red with 51 setup errors from the removed actor. After using actual OP
  device/root records it passed 49 tests / 177 assertions. Two tests solely about physical
  deletion of the retired actor were removed; retained owner-binding FK, refresh/concurrency,
  session limit and retention checks remain. Scoped RuboCop passed. The preceding full-suite
  result predates both realm token test adaptations.

- After the subsequent retired-policy cleanup, the current authentication-context policy
  inventory plus retained cookie invariant passed 4 tests / 548 assertions with no failures or
  errors (`tmp/non-op-current-invariant.log`). The policy inventory still enumerates all remaining
  policy classes; its count differs because retired actor-only policies no longer exist.
- Two additional tests exclusively for retired Zenith contact history and ownership-transfer
  requests were removed. Mixed Chronicle, key-management and credential tests remain to assess.

- Removed the orphaned `ClientSecretClaimFinalizer`, whose only input was the removed Zenith
  credential model and which had no runtime caller. Existing OP receipt and flow rows were not
  changed or marked reconciled. A search now finds no `AppZenithRecord` or `OrgZenithRecord`
  references under app/config/lib; other removed model and connection names still require audit.

- The old session-limit waiting-slot test was Red on its removed actor setup. New APP/ORG
  direct-SQL checks passed 2 tests / 18 assertions, and the existing fail-closed/uniqueness
  batch passed 17 tests / 73 assertions. The remaining legacy concurrency and deadline tests
  require comparison with equivalent retained coverage before any removal.
- Two existing-grant OIDC refresh regressions now use retained OP device, root and grant records
  instead of actor-dependent authorization-code issuance. The prior shared setup was Red on the
  removed actor; both tests passed 16 assertions for rotation, replay rejection, family revocation
  and sibling/root preservation. The many remaining old authorization-code tests in that file
  have not been adapted. Scoped RuboCop passed.

- Reconciled the legacy session-limit test with the unavailable actor contract. The retained
  APP/ORG PostgreSQL CHECK, waiting-slot concurrency using two connections, microsecond deadline
  boundaries, historical rows, mapping, fail-closed and Visa 503 tests passed together: 29 tests /
  179 assertions. Old actor success-flow cases cannot run until Governance authority exists;
  their successful issuance/selection race coverage must be reinstated when that flow returns.
  Scoped RuboCop passed.
- Removed four more confirmed Zenith-only tests after individual review; the retired banner
  query and surface chrome integration are being checked separately.

- Removed the retired banner query, helper, partial, Inertia banner field, React rendering and
  dedicated tests. Other surface chrome is retained. Scoped Ruby lint and TypeScript format/lint
  passed; ApplicationHelper and restricted-mode guard passed 7 tests / 19 assertions. Typecheck
  failed on four previously observed Playwright dependency type mismatches, not on a demonstrated
  banner error. Full frontend verification is still outstanding.
- Current APP/ORG device session boundary suites passed 2 tests / 28 assertions, including
  model and PostgreSQL identifier length checks; those files required no change.

- The mixed email concern test now retains OP ceremony keyed-verifier, binding, deadline,
  cancellation, receipt and direct SQL tamper checks without the retired contact implementation.
  It and related receipt/deadline regressions passed 20 tests / 246 assertions on PostgreSQL;
  scoped RuboCop passed. Old contact-specific lockout belongs to the retired Zenith feature.

- Banner cleanup's remaining surface-layout tests passed 4 cases; application TypeScript
  compilation (`tsc -p tsconfig.app.json --noEmit`) and scoped oxfmt/oxlint succeeded. The full
  `bun run typecheck` remains failed on four Playwright type mismatches already observed in the
  dirty dependency tree.

- The Operator telephone concern test retains OP ceremony proof, deadline, cancellation,
  receipt and direct-SQL tamper coverage without retired contact records. It and related
  reissue/receipt regressions passed 20 tests / 234 assertions on PostgreSQL; scoped RuboCop passed.
- Client Chronicle tests were Red with 17 actor fixture errors. Using retained scalar subject and
  actor IDs, event FK and history assertions, the related Chronicle/audit batch passed 16 tests /
  75 assertions including direct-SQL FK rejection. Scoped lint was being checked.

- Operator Chronicle's old actor-fixture suite was Red with 16 errors. Its retained scalar
  subject/actor, event/level FK, defaults, timestamp/IP and related refresh/halt audit tests
  passed 25 tests / 233 assertions after adaptation; scoped RuboCop passed.
- New APP/ORG HTTP revocation tests and existing logout, refresh, JWKS and discovery regressions
  passed 25 tests / 269 assertions (`tmp/op-endpoints-cross-check.log`). Both realms rejected an
  invalid client assertion, revoked only the requested grant for a signed request, refused its
  subsequent refresh and retained the sibling grant and root. This covers the tested routes and
  fixtures, not an external Governance deployment.

- The OTP lockable test retains the ceremony's infinite-deadline SQL rejection, cancellation
  refusal and writer DB clock checks after retired contact-only cases were removed. PostgreSQL
  passed 2 tests / 7 assertions; scoped RuboCop passed.

- Added and ran actual HTTP discovery/revocation checks for both realms: 2 tests / 48 assertions
  passed, including issuer and advertised token, revocation and JWKS URLs. Scoped RuboCop passed.

- The first isolated fresh-database migration attempt reached the end for all three KEEP
  databases, but the runner exited 1 because the reporting script used an unavailable Rails API.
  Only the three newly created disposable local databases were deleted; a fresh retry with the
  corrected reporting API is in progress. This first attempt is not recorded as final success.
- Removed orphaned old Entra provisioning and contact/secret lookup queries plus five dedicated
  Zenith/setting model test files. The old signup contact-hold test is retained for review because
  collision prevention is security-relevant and must be carried into a future Governance signup
  contract; no unverified claim is made that the new API provides it.

- Fresh Rails migration retry succeeded on three uniquely named local disposable PostgreSQL
  databases at 10.89.0.3: APP 231/231, ORG 193/193 and Chronicle 33/33, all migration exits 0.
  The script verified each actual target before migrating and deleted only those three databases;
  each drop exited 0 (`tmp/keep-fresh-migration-results.json`). This proves empty reconstruction
  only, not migration of existing data or equality with committed dumps. The earlier reporting
  API failure remains recorded above.

- Development `db:verify_no_schema_drift` initially failed and exposed that the ORG writer
  resolved its dump to `db/structure.sql`, the primary database file. Added explicit
  `op_base_org_structure.sql` dump targets in development and test `database.yml`. A direct
  temporary dump comparison after the change matched the current development DB for APP, ORG
  and Chronicle (`tmp/non-op-keep-schema-matches-after.log`). The standard task still exits 1
  and lists all three intentionally changed KEEP dumps plus two RP dumps: it adds every tracked
  schema-file `git diff` to its drift list, so the clean-commit gate is not satisfied in this
  uncommitted worktree. The RP results are outside this task's schema scope. This comparison
  does not substitute for an existing-data migration test.

- The subsequent full Rails suite completed with **7,843 runs / 33,967 assertions / 200
  failures / 2,511 errors / 0 skips** (`tmp/non-op-full-suite-after-adapt.log`), exit 1. Tests
  were loaded while individual retired-only files were being removed and before the subsequent
  ORG dump-path configuration change; this is intermediate evidence, not final validation.
  The large remaining failure set still needs case-by-case work.

- After fixing the ORG dump target, `bin/rails db:abort_if_pending_migrations` and then
  `bin/rails db:prepare` exited 0 in both test and development. The preparatory checks reported
  no pending migrations, so these final prepare runs did not apply queue or other migrations.
  Test used `env -u POSTGRESQL_TEST_PREPARE_DATABASES`; logs are
  `tmp/non-op-{test,dev}-prepare-after.log`.

- The latest standard `RAILS_ENV=test bundle exec database_consistency` returned exit 1 and
  52 findings (`tmp/non-op-consistency-current.log`). Actual model-connection attribution is
  APP 11 + ORG 8 = **KEEP 19**, RP 33, queue 0, unclassified 0. No checker or model exclusion
  was added; the KEEP findings remain open.
- `OpOutboxDispatchJobTest` was Red with 16 missing-actor fixture errors. The retained OP
  device/root version passed 16 tests / 157 assertions, preserving signed logout token,
  issuer/subject/SID, retry, lease and deadline checks; scoped RuboCop passed. The issuer
  consistency integration test also passed 1 test / 22 assertions for both realms, signatures,
  redirects and logout token claims with stored OP subject snapshots.

- The APP/ORG step-up session revocation test was Red with 16 removed-actor setup errors;
  using retained OP root/device records it passed 16 tests / 200 assertions, retaining pending,
  consumed, microsecond deadline, proof burn, history and repeated-revocation checks. Scoped
  RuboCop passed (`tmp/stepup-revocation-op-green.log`).
- Remaining live source references include removed concrete actor and contact models even though
  abstract Zenith record references are gone. In particular, authorization code issuance still
  requires investigation for explicit failure and existing-session contract preservation.

- The selected-actor context test now uses a retained OP device and root while preserving
  selected identity, freshness clearing and token-availability checks: 2 PostgreSQL tests /
  16 assertions passed, as did scoped RuboCop.

- Visa root integration tests now use real OP device/root records and signed JWTs. An initial
  run revealed the test had not issued the pre-existing DBSec challenge required for its expected
  header; after correcting setup without relaxing assertions, 7 tests / 110 assertions passed,
  covering both realms, challenge boundaries, bad audience/signature, replay and cookies. Scoped
  RuboCop passed. This does not establish full-suite success.

- The old authorization-code issuer and coordinator had no live HTTP caller: current APP/ORG
  authorization routes already return unavailable. Their directly callable actor-dependent
  issuance paths now fail before storage access: issuer raises `GovernanceLookupUnavailableError`
  and coordinator returns `temporarily_unavailable` without a redirect. The existing RP redirect
  builders remain. New boundary tests were Red first; with issuer, refresh and token-exchange
  regressions, 11 tests / 86 assertions passed. Scoped RuboCop passed. This does not restore
  authorization issuance before Governance integration.

- A later full `bin/rubocop` run returned exit 1 with 38 offenses across 2,441 inspected files
  (`tmp/non-op-rubocop-after.log`), while `bundle exec erb_lint --lint-all` passed 541 ERB files.
  Examples of remaining RuboCop offenses occur in tracked files with no worktree diff, including
  the empty `test/services/branch_coverage_batch3_services_test.rb` class present at HEAD. The
  dirty `Gemfile.lock` means this alone does not prove every lint result predates all workspace
  changes; the full gate remains failed.

Detailed migration, backfill, historical-reference, receiver, retention, and cutover observations
are recorded in the related same-date evidence files. None of these focused results establishes
full-suite success, fresh-database rebuild success, or zero DatabaseConsistency warnings.

The root-owned focused commands were:

```sh
env -u POSTGRESQL_TEST_PREPARE_DATABASES RUBY_DEBUG_ENABLE=0 RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/services/op_browser_refresh_rotation_test.rb test/services/op_existing_session_refresh_test.rb test/models/op_actor_audit_reference_test.rb test/services/oidc_token_exchange_boundary_test.rb test/values/op_session_token_claims_test.rb
env -u POSTGRESQL_TEST_PREPARE_DATABASES RUBY_DEBUG_ENABLE=0 RAILS_ENV=test PARALLEL_WORKERS=1 bin/rails test test/integration/op_existing_session_logout_test.rb test/models/operator_chronicle_sign_flow_halted_test.rb test/resolvers/op_browser_session_resolver_test.rb
bundle exec erb_lint --lint-all
bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error
```

PostgreSQL tests and the successful standard Brakeman runs required network access to the local
service and package registry respectively. Narrow RuboCop checks run during implementation do
not replace the outstanding full `bin/rubocop` gate.
