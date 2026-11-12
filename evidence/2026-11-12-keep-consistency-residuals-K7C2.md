# KEEP DatabaseConsistency residual assessment

Revision: `f84c87b060876a25994e30e9274420d9067f1367`. The working tree was already heavily
modified and these observations use that uncommitted code, schema, tests, and local fork. This is a
point-in-time assessment, not evidence that the changes are committed or deployed.

`RAILS_ENV=test RUBY_DEBUG_ENABLE=0 bundle exec database_consistency` exited 1 and reported 50
findings: 10 `op_base_app`, 7 `op_base_org`, and 33 RP findings outside this task. The model-to-DB
attribution had no unknown classes; no queue findings appeared. The log is
`tmp/keep-final-17-check.log`. The following table identifies every KEEP finding.

| Checker / model | Reported index or association | Assessment |
| --- | --- | --- |
| UniqueIndex / OperatorAuthCeremonySession | `idx_operator_auth_ceremony_sessions_state_parent` | Partial live-parent index; no matching validation. |
| UniqueIndex / OperatorAuthAdmissionBinding | `idx_operator_admission_active_oidc_purpose` | Partial active parent/purpose index; no matching validation. |
| UniqueIndex / OperatorAuthAdmissionBinding | `idx_operator_admission_active_step_purpose` | Partial active parent/purpose index; no matching validation. |
| UniqueIndex / OperatorStepUpSession | `index_operator_step_up_sessions_on_passkey_challenge_ref` | Nullable unique reference; DB-authoritative named collision retry. |
| UniqueIndex / TurnstileReplay | `index_turnstile_replays_on_token_digest` | DB-authoritative replay detection; no matching validation. |
| UniqueIndex / ClientOidcAuthorizationTransaction | `idx_on_secret_sign_in_flow_id_5c5b1ba175` | Nullable unique historical flow reference; no matching validation. |
| UniqueIndex / ClientAuthCeremonySession | `idx_client_auth_ceremony_sessions_state_parent` | Partial live-parent index; no matching validation. |
| UniqueIndex / ClientAuthAdmissionBinding | `idx_client_admission_active_oidc_purpose` | Partial active parent/purpose index; no matching validation. |
| UniqueIndex / ClientAuthAdmissionBinding | `idx_client_admission_active_step_purpose` | Partial active parent/purpose index; no matching validation. |
| UniqueIndex / ClientStepUpSession | `index_client_step_up_sessions_on_passkey_challenge_ref` | Nullable unique reference; DB-authoritative named collision retry. |
| UniqueIndex / ClientSignUpFlow | `idx_client_signup_one_in_progress_per_admission` | Partial active admission index; no matching validation. |
| ForeignKeyCascade / OperatorStepUpContext | `transitions` | ORM restricts `destroy`; DB cascades deletion. |
| ForeignKeyCascade / OperatorStepUpAuditOutbox | `attempts` | ORM restricts `destroy`; DB cascades deletion. |
| ForeignKey / OpOrgGrant | `operator_token` | No root FK, deliberately allowing historical grant to survive root purge. |
| ForeignKeyCascade / ClientStepUpContext | `transitions` | ORM restricts `destroy`; DB cascades deletion. |
| ForeignKeyCascade / ClientStepUpAuditOutbox | `attempts` | ORM restricts `destroy`; DB cascades deletion. |
| ForeignKey / OpAppGrant | `client_token` | No root FK, deliberately allowing historical grant to survive root purge. |

The unique-index checker correctly observes that these eleven validators are absent. Their database
indexes remain in place. Existing tests and consumers depend on `RecordNotUnique` for these cases:
`test/models/auth_ceremony_session_test.rb`, `test/models/auth_admission_binding_test.rb`,
`test/services/turnstile_replay_store_test.rb`,
`test/models/concerns/oidc_authorization_transactionable_test.rb`, and
`test/models/sign_up_flow_admission_concurrency_test.rb`. Adding a standard uniqueness validation
changes the normal save error to `RecordInvalid` before PostgreSQL can enforce that contract. The
step-up named-index collision contract is recorded in `specs/database-consistency-remediation/cycles.md`
C33; `test/models/op_step_up_passkey_reference_collision_test.rb` verifies the real APP and ORG
retry and exhaustion paths. This review does not assert that every legacy actor-dependent test can
currently run after the ownership split.

The four cascade reports describe real differences between ORM `destroy` and SQL deletion, not
proven checker false positives. The context cascade is required by the OP step-up contract's
15-minute authorization retention (`specs/op-mediated-step-up/contracts/contract-draft.md`,
section 5). The outbox attempts also have explicit cascading FKs. Changing either side solely to
silence the checker would change deletion behavior and potentially audit retention; this assessment
does not establish a new deletion or retention decision.

The two root-FK findings also report a real missing constraint. The absent constraint is intentional:
`specs/op-mediated-step-up/contracts/contract-draft.md` section 5 and the approved owner exception
preserve historical grants when the issuance root is removed. New grant creation still requires an
existing root bound to the device. Adding a root FK or dropping that creation validation would
violate the approved contract. They are not counted as checker false positives.

The local database_consistency 3.0.16 fork has an independently verified general correction for
association presence when the actual foreign-key scalar has unconditional presence. The old checker
incorrectly reported two grant NOT NULL findings despite that scalar validation. PostgreSQL specs
also cover conditional scalar validation, polymorphic type independence and missing NOT NULL; the
fork's full relevant PostgreSQL regression batch passed 53 examples. The tracked patch and README
carry that fix; no configuration, checker disabling or model exclusion was added. The fork is local
and must be applied from the tracked patch to the recorded exact fork revision; an unpatched install
is not established to behave the same way.

The remaining 17 KEEP findings have not been eliminated. The eleven missing validators and four
delete-policy differences need contract-preserving design work; the two intentional absent FKs
need a checker model capable of expressing that history contract, without exclusions, before zero
findings can be claimed. This document does not prove an application-wide audit, a passing test
suite, or a production migration.

## Subsequent changes in the same working tree

The 17-finding assessment above describes the earlier run, not the current count. The later standard
checker run `tmp/auth-active-parent-checker-final2.log` exited 1 with 41 findings: 8 KEEP and 33
out-of-scope RP. The root owner aligned the four step-up child associations with their existing
`ON DELETE CASCADE` database contract. The unique sign-in-flow reference on
`ClientOidcAuthorizationTransaction` now has a model validator; its direct SQL and two-connection
PostgreSQL race tests still exercise `RecordNotUnique`, while an ordinary duplicate update returns
`RecordInvalid`. The existing direct-operation test was updated to assert both layers. Its focused
suite passed three tests / 28 assertions, and the existing history/FK test passed one test / ten
assertions. No FK or index was removed.

Both realm admission-binding models now validate active uniqueness per parent and purpose, with the
existing partial indexes unchanged. The old direct `create!` assertions now separately check ordinary
`RecordInvalid` and SQL `RecordNotUnique`; the new two-connection tests cover the native index race,
independent purposes and retired history. The focused batch passed 20 tests / 289 assertions. The
coordinator has a narrow retry for an otherwise-valid parent uniqueness conflict; its new
`RecordInvalid` retry branch has not yet been independently exercised. A same-browser retry and
foreign-browser refusal integration check is pending.

The checker initially failed to recognize these correct validations because PostgreSQL's partial
index adds `parent_id IS NOT NULL` while the validator uses `allow_nil` and the same remaining
status predicate. The general checker fix recognizes that exact conjunct only when nil is skipped;
its PostgreSQL regressions continue to reject different guard columns, different status predicates,
OR predicates and validators that do not skip nil. The relevant fork batch passed 79 examples,
with scoped fork and application RuboCop passing. The regenerated patch applied cleanly to the
recorded fork revision and matched all nine modified/added files byte for byte. No model or checker
was excluded.

The eight current KEEP findings are the two intentionally absent issuance-root FKs listed above and
six UniqueIndex findings: APP/ORG AuthCeremonySession's live-parent index, APP/ORG StepUpSession's
passkey reference, TurnstileReplay token digest, and ClientSignUpFlow's active admission. These
remain unresolved; their database indexes remain in place. The RP and Solid Queue scope remains
unchanged.
