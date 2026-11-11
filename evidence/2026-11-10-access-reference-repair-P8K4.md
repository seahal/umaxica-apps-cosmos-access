# Access reference catalog repair

Date: 2026-11-10 UTC. Full HEAD: `281a9e5c539bc0b89b4d37ff5bd6f102976ad4c4`. Extensive pre-existing
uncommitted changes affect the runtime and test results. This repair adds only five fixture source
changes and this evidence file; it does not certify pristine HEAD.

## Authorization and method

Owner authorization: user instruction dated 2026-11-10; inventory:
[catalog audit](2026-11-09-access-reference-catalog-audit-N3R7.md). Acceptance: add only the
approved missing fixed catalog rows, reconstruct the test catalogs from source, recount Visa/Auth
references, and run related tests and security tests.

The running executor is a container (`/run/.containerenv` exists), with the documented Ruby runtime
and Compose-local PostgreSQL services. Managed cloud environment status tooling is unavailable. No
external service calls or commits were performed.

Fresh read-only catalog comparison reproduced development missing 46 rows in the authorized eleven
current-model tables and test missing 13 rows in five tables before writes. The complete development
comparison also found five excluded missing rows in two retained tables. The development repair
process booted Rails with read-only PostgreSQL transactions, null application logging and
OpenTelemetry disabled. It checked all eleven missing counts and the aggregate before opening write
connections. It opened transactions on all four owning writer databases, locked only the eleven
reference tables, and rechecked the same counts before inserting. No development database
preparation, reset, schema change or deletion ran.

Nine tables used the existing `ensure_defaults!` writer. Registration completion methods used
`create!` for missing entries from the model `IDS` mapping. Processor notification statuses used
missing-only `insert_all!` with the complete original seed row shape and the later delivery-contract
amendment. The historical migration methods were never executed. Its assembled identifier set was
checked against model `DEFAULTS`. Existing rows were compared in memory before and after each table
operation; all were unchanged. Each table had zero missing identifiers before its transaction
committed. All transactions completed successfully.

Processor row-shape sources:
`db/app_principals_migrate/20260703020000_create_client_privacy_and_retention_tables.rb` and
`db/app_principals_migrate/20260923140000_add_client_processor_delivery_contract.rb`. Registration
mapping owner: `app/models/client_registration_completion_method.rb`. No reference identifier or row
value is retained in this record.

## Development results

| Table                                            | Missing before | Inserted | Missing after |
| ------------------------------------------------ | -------------: | -------: | ------------: |
| `client_step_up_audit_outbox_delivery_states`    |              2 |        2 |             0 |
| `client_step_up_context_states`                  |              5 |        5 |             0 |
| `operator_step_up_audit_outbox_delivery_states`  |              2 |        2 |             0 |
| `operator_step_up_context_states`                |              5 |        5 |             0 |
| `client_preference_statuses`                     |              2 |        2 |             0 |
| `client_privacy_request_statuses`                |              9 |        9 |             0 |
| `client_processor_erasure_notification_statuses` |              5 |        5 |             0 |
| `client_registration_completion_methods`         |              4 |        4 |             0 |
| `client_retention_hold_statuses`                 |              3 |        3 |             0 |
| `client_withdrawal_flow_statuses`                |              7 |        7 |             0 |
| `operator_preference_statuses`                   |              2 |        2 |             0 |
| **Total**                                        |         **46** |   **46** |         **0** |

## Test reconstruction and results

Updated the existing `test/fixtures/client_statuses.yml`, `test/fixtures/division_statuses.yml`, and
`test/fixtures/operator_secret_credential_kinds.yml` by retaining their existing named fixtures and
adding the remaining model `DEFAULTS` entries through ERB. Existing entries are excluded using their
model constants, preserving fixture labels without duplicate identifiers. Added
`test/fixtures/operator_entra_identity_states.yml` and
`test/fixtures/organization_entra_connection_states.yml`, each with an explicit model mapping and an
ERB loop over its owning model `DEFAULTS`. No literal catalog values were added. The existing
`fixtures :all` setup picks up these sources on future runs; no production code or global test setup
changed.

Executed successfully (exit 0), test environment only:

```sh
RAILS_ENV=test OTEL_SDK_DISABLED=true bin/rails db:test:prepare
RAILS_ENV=test OTEL_SDK_DISABLED=true FIXTURES=client_statuses,division_statuses,operator_entra_identity_states,operator_secret_credential_kinds,organization_entra_connection_states bin/rails db:fixtures:load
```

The scoped fixture reload reconstructed 27 canonical rows in the five test tables. “Added missing”
below is the number of formerly absent canonical identifiers, not the number of INSERT statements
during fixture replacement. Test fixtures are disposable; this replacement is confined to the
approved test tables. Read-only comparison after reconstruction and again after the test runs
confirmed zero missing identifiers.

| Table                                  | Missing before | Added missing | Missing after |
| -------------------------------------- | -------------: | ------------: | ------------: |
| `client_statuses`                      |              1 |             1 |             0 |
| `division_statuses`                    |              3 |             3 |             0 |
| `operator_entra_identity_states`       |              4 |             4 |             0 |
| `operator_secret_credential_kinds`     |              1 |             1 |             0 |
| `organization_entra_connection_states` |              4 |             4 |             0 |
| **Total**                              |         **13** |        **13** |         **0** |

## Visa/Auth catalog recount

Repeated the audit comparison using current model constants and explicit migration catalogs,
matching identifier membership rather than total row count. All 70 comparable tables were checked in
both environments, including both Visa/Auth OP writer catalogs. Application boot for model
inspection was read-only; subsequent comparisons were count-only SELECTs with read-only
transactions. Results after repair and after tests agreed: development retains only the two excluded
tables below; test has zero missing across all 70. Three unresolved catalogs remain unclassified and
untouched; this is not a claim that their workflows are complete or that every non-PK column in
already-existing rows is certified.

| Table                                              | Development missing | Test missing |
| -------------------------------------------------- | ------------------: | -----------: |
| `client_auth_admission_binding_statuses`           |                   0 |            0 |
| `client_auth_ceremony_session_statuses`            |                   0 |            0 |
| `client_oidc_authorization_transaction_statuses`   |                   0 |            0 |
| `client_session_limit_resolution_states`           |                   0 |            0 |
| `client_sign_in_flow_states`                       |                   0 |            0 |
| `client_sign_up_flow_cleanup_statuses`             |                   0 |            0 |
| `client_sign_up_flow_statuses`                     |                   0 |            0 |
| `client_step_up_audit_outbox_delivery_states`      |                   0 |            0 |
| `client_step_up_context_states`                    |                   0 |            0 |
| `client_token_binding_methods`                     |                   0 |            0 |
| `client_token_dbsc_statuses`                       |                   0 |            0 |
| `client_token_kinds`                               |                   0 |            0 |
| `client_token_statuses`                            |                   0 |            0 |
| `op_app_authority_stop_causes`                     |                   0 |            0 |
| `op_app_authority_stop_participant_statuses`       |                   0 |            0 |
| `op_app_authority_stop_scopes`                     |                   0 |            0 |
| `op_org_authority_stop_causes`                     |                   0 |            0 |
| `op_org_authority_stop_participant_statuses`       |                   0 |            0 |
| `op_org_authority_stop_scopes`                     |                   0 |            0 |
| `operator_auth_admission_binding_statuses`         |                   0 |            0 |
| `operator_auth_ceremony_session_statuses`          |                   0 |            0 |
| `operator_oidc_authorization_transaction_statuses` |                   0 |            0 |
| `operator_session_limit_resolution_states`         |                   0 |            0 |
| `operator_sign_in_flow_states`                     |                   0 |            0 |
| `operator_sign_up_flow_statuses`                   |                   0 |            0 |
| `operator_step_up_audit_outbox_delivery_states`    |                   0 |            0 |
| `operator_step_up_context_states`                  |                   0 |            0 |
| `operator_token_binding_methods`                   |                   0 |            0 |
| `operator_token_dbsc_statuses`                     |                   0 |            0 |
| `operator_token_kinds`                             |                   0 |            0 |
| `operator_token_statuses`                          |                   0 |            0 |
| `client_email_statuses`                            |                   0 |            0 |
| `client_identity_states`                           |                   0 |            0 |
| `client_mfa_statuses`                              |                   0 |            0 |
| `client_passkey_statuses`                          |                   0 |            0 |
| `client_preference_statuses`                       |                   0 |            0 |
| `client_privacy_request_statuses`                  |                   0 |            0 |
| `client_processor_erasure_notification_statuses`   |                   0 |            0 |
| `client_registration_completion_methods`           |                   0 |            0 |
| `client_retention_hold_statuses`                   |                   0 |            0 |
| `client_security_modes`                            |                   0 |            0 |
| `client_statuses`                                  |                   0 |            0 |
| `client_telephone_statuses`                        |                   0 |            0 |
| `client_totp_credential_statuses`                  |                   0 |            0 |
| `client_visibilities`                              |                   0 |            0 |
| `client_withdrawal_flow_statuses`                  |                   0 |            0 |
| `member_statuses`                                  |                   0 |            0 |
| `persona_membership_kinds`                         |                   0 |            0 |
| `persona_membership_states`                        |                   0 |            0 |
| `agent_membership_kinds`                           |                   0 |            0 |
| `agent_membership_states`                          |                   0 |            0 |
| `department_statuses`                              |                   0 |            0 |
| `division_statuses`                                |                   0 |            0 |
| `operator_email_statuses`                          |                   0 |            0 |
| `operator_entra_identity_states`                   |                   0 |            0 |
| `operator_identity_states`                         |                   0 |            0 |
| `operator_mfa_statuses`                            |                   0 |            0 |
| `operator_passkey_statuses`                        |                   0 |            0 |
| `operator_preference_statuses`                     |                   0 |            0 |
| `operator_secret_credential_kinds`                 |                   0 |            0 |
| `operator_secret_credential_statuses`              |                   0 |            0 |
| `operator_security_modes`                          |                   0 |            0 |
| `operator_statuses`                                |                   0 |            0 |
| `operator_telephone_statuses`                      |                   0 |            0 |
| `operator_visibilities`                            |                   0 |            0 |
| `operator_workspace_account_statuses`              |                   0 |            0 |
| `organization_entra_connection_states`             |                   0 |            0 |
| `organization_statuses`                            |                   0 |            0 |
| `staff_identity_statuses`                          |                   3 |            0 |
| `workspace_statuses`                               |                   2 |            0 |

Excluded retained tables: `staff_identity_statuses` and `workspace_statuses` (five missing
development rows combined). Unresolved and untouched: `client_profile_statuses`,
`legacy_replaced_client_statuses`, `operator_google_identity_statuses`. No owner or catalog was
inferred.

## Verification

Related tests ran with `OTEL_SDK_DISABLED=true PARALLEL_WORKERS=2 bin/rails test` and the following
27 paths:

- `test/models/client_step_up_context_test.rb`
- `test/models/operator_step_up_context_test.rb`
- `test/models/client_step_up_context_state_test.rb`
- `test/models/operator_step_up_context_state_test.rb`
- `test/models/client_step_up_audit_outbox_test.rb`
- `test/models/operator_step_up_audit_outbox_test.rb`
- `test/models/client_step_up_audit_outbox_delivery_state_test.rb`
- `test/models/operator_step_up_audit_outbox_delivery_state_test.rb`
- `test/models/client_withdrawal_flow_test.rb`
- `test/models/withdrawal_flow_test.rb`
- `test/models/client_withdrawal_ceremony_test.rb`
- `test/models/operator_withdrawal_test.rb`
- `test/services/withdrawal_lifecycle_test.rb`
- `test/integration/withdrawal_lifecycle_security_test.rb`
- `test/models/client_privacy_request_test.rb`
- `test/models/client_retention_hold_test.rb`
- `test/models/client_processor_erasure_notification_test.rb`
- `test/models/processor_erasure_notification_delivery_contract_test.rb`
- `test/models/processor_erasure_notification_state_test.rb`
- `test/models/division_test.rb`
- `test/models/operator_secret_credential_kind_test.rb`
- `test/models/operator_entra_identity_test.rb`
- `test/models/organization_entra_connection_test.rb`
- `test/operations/app_sign_up_registration_receipt_test.rb`
- `test/integration/email_signup_base_root_completion_test.rb`
- `test/integration/app_secret_signup_journey_test.rb`
- `test/controllers/auth/step_up_admission_test.rb`

Result: **166 runs, 2113 assertions, 1 failure, 0 errors, 0 skips**, exit 1. The failure is
`EmailSignupBaseRootCompletionTest#test_app_email_signup_binds_its_original_OIDC_browser_and_Visa_commits_exactly_one_root`,
at `test/integration/email_signup_base_root_completion_test.rb:108`: the initial GET on the Base
host expects HTTP 200 and receives HTTP 404, before registration completion is reached. Current
`config/routes.rb` draws Auth and Visa and omits Base. This is a pre-existing route/test contract
discrepancy in the uncommitted worktree, independent of fixture catalog membership; no
pristine-baseline run was performed. No route or test expectation was changed. The other 165 tests
passed, including the registration receipt and signup journey tests. End-to-end completion through
this retired Base entry remains unverified.

`OTEL_SDK_DISABLED=true PARALLEL_WORKERS=2 bin/rails test test/security`: **144 runs, 817
assertions, 0 failures, 0 errors, 0 skips**, exit 0.

`git diff --check` on the three existing modified fixture files passed. Fixture ERB/YAML loading and
model resolution were exercised successfully by the scoped fixture load and the behavior tests. No
environment-construction tests were added, no validators or required associations were weakened, and
no application Ruby was changed. Full CI was not run; verification was scoped to fixture
reconstruction, related behavior, and the requested security suite.

## Limits

The missing-reference class of the earlier 422 is resolved for the authorized and comparable
catalogs at query time. This record does not certify all endpoints or undefined catalogs.
Development retained data, audit history and non-reference tables were not repaired or cleaned up.
No reference row values are included in the evidence.
