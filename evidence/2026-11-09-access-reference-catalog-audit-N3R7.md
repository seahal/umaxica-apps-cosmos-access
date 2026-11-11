# Access reference catalog audit

Date: 2026-11-09 UTC. Full HEAD: `281a9e5c539bc0b89b4d37ff5bd6f102976ad4c4`. The worktree contains
extensive pre-existing uncommitted changes and concurrent authorized tool retirement work. Current
model/migration files and the available local development/test databases, rather than pristine HEAD,
determine these observations. This audit edits only this evidence file.

## Scope and method

Reconciled all 73 reference-table pairs from `evidence/2026-11-09-access-reference-data-R6K2.md`,
across the development and test writer databases for `op_base_app`, `op_base_org`, `app_zenith`, and
`org_zenith`. Runtime OAuth callback and DPoP proof state tables remain excluded. No database
writes, migrations, resets, external calls, credentials changes or commits were performed. No ID
values or row contents are retained here.

A temporary diagnostic Rails process booted with
`PGOPTIONS='-c default_transaction_read_only=on -c statement_timeout=15000'`, logging directed to
the null sink and OpenTelemetry disabled. It inspected each named reference model's constants; 59
tables expose `DEFAULTS`. This was diagnostic constant inspection, not application dispatch. The
fixed catalog definitions for eleven further tables came from the explicit sources below. No
migration up/change methods or seed writers ran. Direct `psql -XAt -v ON_ERROR_STOP=1` SELECTs
against local `primary`, also forced read-only, compared each canonical ID set with actual IDs.
Queries returned only total, required-present, required-missing and extra counts. Equality of row
counts was never substituted for ID membership. Three tables have no recoverable explicit current
catalog and are marked unresolved instead of guessing their contents.

Temporary commands: `bundle exec ruby /tmp/access_catalog_model_probe.rb`,
`python3 /tmp/access_catalog_compare.py`, and count-only registration-key comparison SELECTs. The
final comparisons completed successfully. The non-PK `key` mapping on registration completion
methods was also checked against the model `IDS`: zero existing-row mismatches in either
environment. A zero mismatch with zero rows does not establish completeness; missing IDs are counted
separately. The other non-PK name columns are not certified by the ID-set comparison; any future
replay must preserve the complete owning migration row shape, including processor notification
names.

## Findings

- 70 of 73 tables have an explicit ID catalog that could be compared in each environment.
- Development: 51 catalog IDs missing in 13 tables. Of these, 46 are in eleven tables with current
  models; five belong to two retained tables without current models and need an ownership decision.
- Test: 13 catalog IDs missing in five tables with current models. No test data was repaired.
- The six previously approved and repaired authorization/admission/session catalogs are complete in
  both environments. No new reference data was inserted by this audit.
- Extra IDs are reported separately, not proposed for deletion. This audit grants no cleanup
  authority and does not infer a problem merely from a retained extra reference row.
- These are observations at query time, not an assurance that a concurrently used test database
  remains unchanged or that tables outside the original inventory are complete.

## Exact ID catalog comparison

`Req` is the unique canonical ID count. Each environment cell is
`total rows / required present / required missing / extra`. `?` means no explicit current catalog
was established; only the total row count is known. Presence of all IDs certifies ID coverage, not
every non-PK column or every workflow using the table.

| Owner       | Table                                              | Req | Development: total / present / missing / extra | Test: total / present / missing / extra |
| ----------- | -------------------------------------------------- | --: | ---------------------------------------------- | --------------------------------------- |
| app_zenith  | `client_email_statuses`                            |   7 | 7 / 7 / 0 / 0                                  | 7 / 7 / 0 / 0                           |
| app_zenith  | `client_identity_states`                           |   4 | 4 / 4 / 0 / 0                                  | 4 / 4 / 0 / 0                           |
| app_zenith  | `client_mfa_statuses`                              |   3 | 3 / 3 / 0 / 0                                  | 3 / 3 / 0 / 0                           |
| app_zenith  | `client_passkey_statuses`                          |   5 | 5 / 5 / 0 / 0                                  | 5 / 5 / 0 / 0                           |
| app_zenith  | `client_preference_statuses`                       |   2 | 0 / 0 / 2 / 0                                  | 2 / 2 / 0 / 0                           |
| app_zenith  | `client_privacy_request_statuses`                  |   9 | 0 / 0 / 9 / 0                                  | 9 / 9 / 0 / 0                           |
| app_zenith  | `client_processor_erasure_notification_statuses`   |   5 | 0 / 0 / 5 / 0                                  | 5 / 5 / 0 / 0                           |
| app_zenith  | `client_profile_statuses`                          |   ? | 0 / ? / ? / ?                                  | 1 / ? / ? / ?                           |
| app_zenith  | `client_registration_completion_methods`           |   4 | 0 / 0 / 4 / 0                                  | 4 / 4 / 0 / 0                           |
| app_zenith  | `client_retention_hold_statuses`                   |   3 | 0 / 0 / 3 / 0                                  | 3 / 3 / 0 / 0                           |
| app_zenith  | `client_security_modes`                            |   2 | 2 / 2 / 0 / 0                                  | 2 / 2 / 0 / 0                           |
| app_zenith  | `client_statuses`                                  |  13 | 13 / 13 / 0 / 0                                | 12 / 12 / 1 / 0                         |
| app_zenith  | `client_telephone_statuses`                        |   8 | 8 / 8 / 0 / 0                                  | 8 / 8 / 0 / 0                           |
| app_zenith  | `client_totp_credential_statuses`                  |   5 | 5 / 5 / 0 / 0                                  | 5 / 5 / 0 / 0                           |
| app_zenith  | `client_visibilities`                              |   4 | 4 / 4 / 0 / 0                                  | 4 / 4 / 0 / 0                           |
| app_zenith  | `client_withdrawal_flow_statuses`                  |   7 | 0 / 0 / 7 / 0                                  | 7 / 7 / 0 / 0                           |
| app_zenith  | `legacy_replaced_client_statuses`                  |   ? | 0 / ? / ? / ?                                  | 5 / ? / ? / ?                           |
| app_zenith  | `member_statuses`                                  |   5 | 5 / 5 / 0 / 0                                  | 5 / 5 / 0 / 0                           |
| app_zenith  | `persona_membership_kinds`                         |   4 | 4 / 4 / 0 / 0                                  | 4 / 4 / 0 / 0                           |
| app_zenith  | `persona_membership_states`                        |   6 | 6 / 6 / 0 / 0                                  | 6 / 6 / 0 / 0                           |
| op_base_app | `client_auth_admission_binding_statuses`           |   6 | 6 / 6 / 0 / 0                                  | 6 / 6 / 0 / 0                           |
| op_base_app | `client_auth_ceremony_session_statuses`            |   8 | 8 / 8 / 0 / 0                                  | 8 / 8 / 0 / 0                           |
| op_base_app | `client_oidc_authorization_transaction_statuses`   |   4 | 4 / 4 / 0 / 0                                  | 4 / 4 / 0 / 0                           |
| op_base_app | `client_session_limit_resolution_states`           |   5 | 5 / 5 / 0 / 0                                  | 5 / 5 / 0 / 0                           |
| op_base_app | `client_sign_in_flow_states`                       |  14 | 14 / 14 / 0 / 0                                | 14 / 14 / 0 / 0                         |
| op_base_app | `client_sign_up_flow_cleanup_statuses`             |   5 | 5 / 5 / 0 / 0                                  | 5 / 5 / 0 / 0                           |
| op_base_app | `client_sign_up_flow_statuses`                     |  15 | 15 / 15 / 0 / 0                                | 15 / 15 / 0 / 0                         |
| op_base_app | `client_step_up_audit_outbox_delivery_states`      |   2 | 0 / 0 / 2 / 0                                  | 2 / 2 / 0 / 0                           |
| op_base_app | `client_step_up_context_states`                    |   5 | 0 / 0 / 5 / 0                                  | 5 / 5 / 0 / 0                           |
| op_base_app | `client_token_binding_methods`                     |   3 | 3 / 3 / 0 / 0                                  | 3 / 3 / 0 / 0                           |
| op_base_app | `client_token_dbsc_statuses`                       |   5 | 5 / 5 / 0 / 0                                  | 5 / 5 / 0 / 0                           |
| op_base_app | `client_token_kinds`                               |   3 | 3 / 3 / 0 / 0                                  | 3 / 3 / 0 / 0                           |
| op_base_app | `client_token_statuses`                            |   5 | 5 / 5 / 0 / 0                                  | 5 / 5 / 0 / 0                           |
| op_base_app | `op_app_authority_stop_causes`                     |   9 | 9 / 9 / 0 / 0                                  | 9 / 9 / 0 / 0                           |
| op_base_app | `op_app_authority_stop_participant_statuses`       |   4 | 4 / 4 / 0 / 0                                  | 4 / 4 / 0 / 0                           |
| op_base_app | `op_app_authority_stop_scopes`                     |   3 | 3 / 3 / 0 / 0                                  | 3 / 3 / 0 / 0                           |
| op_base_org | `op_org_authority_stop_causes`                     |   9 | 9 / 9 / 0 / 0                                  | 9 / 9 / 0 / 0                           |
| op_base_org | `op_org_authority_stop_participant_statuses`       |   4 | 4 / 4 / 0 / 0                                  | 4 / 4 / 0 / 0                           |
| op_base_org | `op_org_authority_stop_scopes`                     |   3 | 3 / 3 / 0 / 0                                  | 3 / 3 / 0 / 0                           |
| op_base_org | `operator_auth_admission_binding_statuses`         |   6 | 6 / 6 / 0 / 0                                  | 6 / 6 / 0 / 0                           |
| op_base_org | `operator_auth_ceremony_session_statuses`          |   8 | 8 / 8 / 0 / 0                                  | 8 / 8 / 0 / 0                           |
| op_base_org | `operator_oidc_authorization_transaction_statuses` |   4 | 4 / 4 / 0 / 0                                  | 4 / 4 / 0 / 0                           |
| op_base_org | `operator_session_limit_resolution_states`         |   5 | 5 / 5 / 0 / 0                                  | 5 / 5 / 0 / 0                           |
| op_base_org | `operator_sign_in_flow_states`                     |  14 | 14 / 14 / 0 / 0                                | 14 / 14 / 0 / 0                         |
| op_base_org | `operator_sign_up_flow_statuses`                   |   9 | 9 / 9 / 0 / 0                                  | 9 / 9 / 0 / 0                           |
| op_base_org | `operator_step_up_audit_outbox_delivery_states`    |   2 | 0 / 0 / 2 / 0                                  | 2 / 2 / 0 / 0                           |
| op_base_org | `operator_step_up_context_states`                  |   5 | 0 / 0 / 5 / 0                                  | 5 / 5 / 0 / 0                           |
| op_base_org | `operator_token_binding_methods`                   |   3 | 3 / 3 / 0 / 0                                  | 3 / 3 / 0 / 0                           |
| op_base_org | `operator_token_dbsc_statuses`                     |   5 | 5 / 5 / 0 / 0                                  | 5 / 5 / 0 / 0                           |
| op_base_org | `operator_token_kinds`                             |   3 | 3 / 3 / 0 / 0                                  | 3 / 3 / 0 / 0                           |
| op_base_org | `operator_token_statuses`                          |   5 | 5 / 5 / 0 / 0                                  | 5 / 5 / 0 / 0                           |
| org_zenith  | `agent_membership_kinds`                           |   4 | 4 / 4 / 0 / 0                                  | 4 / 4 / 0 / 0                           |
| org_zenith  | `agent_membership_states`                          |   6 | 6 / 6 / 0 / 0                                  | 6 / 6 / 0 / 0                           |
| org_zenith  | `department_statuses`                              |   4 | 4 / 4 / 0 / 0                                  | 4 / 4 / 0 / 0                           |
| org_zenith  | `division_statuses`                                |   4 | 4 / 4 / 0 / 0                                  | 1 / 1 / 3 / 0                           |
| org_zenith  | `operator_email_statuses`                          |   7 | 7 / 7 / 0 / 0                                  | 7 / 7 / 0 / 0                           |
| org_zenith  | `operator_entra_identity_states`                   |   4 | 4 / 4 / 0 / 0                                  | 0 / 0 / 4 / 0                           |
| org_zenith  | `operator_google_identity_statuses`                |   ? | 0 / ? / ? / ?                                  | 0 / ? / ? / ?                           |
| org_zenith  | `operator_identity_states`                         |   4 | 4 / 4 / 0 / 0                                  | 4 / 4 / 0 / 0                           |
| org_zenith  | `operator_mfa_statuses`                            |   3 | 3 / 3 / 0 / 0                                  | 3 / 3 / 0 / 0                           |
| org_zenith  | `operator_passkey_statuses`                        |   2 | 2 / 2 / 0 / 0                                  | 2 / 2 / 0 / 0                           |
| org_zenith  | `operator_preference_statuses`                     |   2 | 0 / 0 / 2 / 0                                  | 2 / 2 / 0 / 0                           |
| org_zenith  | `operator_secret_credential_kinds`                 |   2 | 2 / 2 / 0 / 0                                  | 1 / 1 / 1 / 0                           |
| org_zenith  | `operator_secret_credential_statuses`              |   5 | 5 / 5 / 0 / 0                                  | 5 / 5 / 0 / 0                           |
| org_zenith  | `operator_security_modes`                          |   2 | 2 / 2 / 0 / 0                                  | 2 / 2 / 0 / 0                           |
| org_zenith  | `operator_statuses`                                |   3 | 3 / 3 / 0 / 0                                  | 3 / 3 / 0 / 0                           |
| org_zenith  | `operator_telephone_statuses`                      |   7 | 7 / 7 / 0 / 0                                  | 7 / 7 / 0 / 0                           |
| org_zenith  | `operator_visibilities`                            |   4 | 4 / 4 / 0 / 0                                  | 4 / 4 / 0 / 0                           |
| org_zenith  | `operator_workspace_account_statuses`              |   2 | 2 / 2 / 0 / 0                                  | 2 / 2 / 0 / 0                           |
| org_zenith  | `organization_entra_connection_states`             |   4 | 4 / 4 / 0 / 0                                  | 0 / 0 / 4 / 0                           |
| org_zenith  | `organization_statuses`                            |   1 | 1 / 1 / 0 / 0                                  | 1 / 1 / 0 / 0                           |
| org_zenith  | `staff_identity_statuses`                          |   3 | 0 / 0 / 3 / 0                                  | 3 / 3 / 0 / 0                           |
| org_zenith  | `workspace_statuses`                               |   2 | 0 / 0 / 2 / 0                                  | 2 / 2 / 0 / 0                           |

## Missing current catalogs — approval required before any development insert

This is an insertion candidate inventory, not an executed repair. The table-specific counts below
are the maximum missing rows observed; re-read and compare before any approved replay. The owner has
not authorized these writes. Registration completion methods need the full ID/key catalog, not an
ID-only insert. Processor notification status replay needs the original seed plus the later
delivery-contract amendment; do not invent name values or omit required columns.

| Development owner | Current reference table                          | Missing rows | Definition                                                             |
| ----------------- | ------------------------------------------------ | -----------: | ---------------------------------------------------------------------- |
| op_base_app       | `client_step_up_audit_outbox_delivery_states`    |            2 | `app/models/client_step_up_audit_outbox_delivery_state.rb::DEFAULTS`   |
| op_base_app       | `client_step_up_context_states`                  |            5 | `app/models/client_step_up_context_state.rb::DEFAULTS`                 |
| op_base_org       | `operator_step_up_audit_outbox_delivery_states`  |            2 | `app/models/operator_step_up_audit_outbox_delivery_state.rb::DEFAULTS` |
| op_base_org       | `operator_step_up_context_states`                |            5 | `app/models/operator_step_up_context_state.rb::DEFAULTS`               |
| app_zenith        | `client_preference_statuses`                     |            2 | `app/models/client_preference_status.rb::DEFAULTS`                     |
| app_zenith        | `client_privacy_request_statuses`                |            9 | `app/models/client_privacy_request_status.rb::DEFAULTS`                |
| app_zenith        | `client_processor_erasure_notification_statuses` |            5 | `app/models/client_processor_erasure_notification_status.rb::DEFAULTS` |
| app_zenith        | `client_registration_completion_methods`         |            4 | `app/models/client_registration_completion_method.rb::IDS`             |
| app_zenith        | `client_retention_hold_statuses`                 |            3 | `app/models/client_retention_hold_status.rb::DEFAULTS`                 |
| app_zenith        | `client_withdrawal_flow_statuses`                |            7 | `app/models/client_withdrawal_flow_status.rb::DEFAULTS`                |
| org_zenith        | `operator_preference_statuses`                   |            2 | `app/models/operator_preference_status.rb::DEFAULTS`                   |

Total current-model development candidate rows: **46**, across **11** tables.

Test catalog gaps (count-only, no repair performed):

| Test owner | Current reference table                | Missing rows | Definition                                                    |
| ---------- | -------------------------------------- | -----------: | ------------------------------------------------------------- |
| app_zenith | `client_statuses`                      |            1 | `app/models/client_status.rb::DEFAULTS`                       |
| org_zenith | `division_statuses`                    |            3 | `app/models/division_status.rb::DEFAULTS`                     |
| org_zenith | `operator_entra_identity_states`       |            4 | `app/models/operator_entra_identity_state.rb::DEFAULTS`       |
| org_zenith | `operator_secret_credential_kinds`     |            1 | `app/models/operator_secret_credential_kind.rb::DEFAULTS`     |
| org_zenith | `organization_entra_connection_states` |            4 | `app/models/organization_entra_connection_state.rb::DEFAULTS` |

## Definitions without DEFAULTS

The following explicit sources were read without executing their writers:

- App and Org authority-stop causes, scopes and participant statuses: the `CAUSES`, `SCOPES` and
  `PARTICIPANT_STATUSES` hash keys in
  `db/op_base_app_migrate/20261025120000_create_op_authority_stops_op_base_app.rb` and
  `db/op_base_org_migrate/20261025120000_create_op_authority_stops_op_base_org.rb`. All six tables
  have exact complete coverage in both environments.
- `app/models/operator_passkey_status.rb`: both fixed integer constants. Exact complete coverage.
- `app/models/operator_secret_credential_status.rb`: five fixed integer constants. Exact complete
  coverage.
- `app/models/client_registration_completion_method.rb::IDS`, cross-checked with
  `db/app_zenith_migrate/20261102064911_seed_client_registration_completion_methods.rb`.
- Retained `staff_identity_statuses`: three fixed catalog entries in
  `db/org_principals_migrate/20260202260000_replace_code_with_fixed_ids.rb`. Development misses all
  three; test covers all three. No matching current model or current application table reference was
  found. Establish continued ownership before proposing retained-table writes.
- Retained `workspace_statuses`: the entry in
  `db/org_principals_migrate/20260212000003_ensure_seed_reference_data_in_operators.rb` plus the
  separate sentinel seed in
  `db/org_principals_migrate/20260329151000_seed_workspace_status_nothing_zero.rb`. Development
  misses both; test covers both. No matching current model or current application table reference
  was found. These five retained-table rows are separate from the 46 current-model candidates and
  are not included in an automatic repair proposal.

## Unresolved catalog ownership/definition (three tables)

- `client_profile_statuses`: current `ClientProfileStatus` and `ClientProfile` models exist, but no
  DEFAULTS, fixed constants or explicit reference seed was found. The owning
  `db/app_zenith_migrate/20260519172000_create_client_profile_tables.rb` creates the table and two
  required foreign keys whose columns have the same default sentinel. Development has no rows; test
  has one. That default is an observable prerequisite, but it does not define a complete semantic
  catalog or justify copying a test fixture into development. A canonical catalog and owner decision
  are required before insertion. No expected IDs are guessed in the table above.
- `legacy_replaced_client_statuses`: deliberately renamed from the old principal catalog in
  `db/app_principals_migrate/20260520143000_rename_app_principal_tables_to_model_conventions.rb`.
  Its previous conversion in
  `db/app_principals_migrate/20260131140000_convert_client_statuses_to_smallint.rb` generated IDs
  from historical row ordering, so the current files do not define a standalone fixed set that can
  be replayed safely. No current model found. Development has no rows; test has five. Do not treat
  five test rows as an authoritative seed specification.
- `operator_google_identity_statuses`: renamed from `operator_social_google_statuses` by
  `db/org_principals_migrate/20260530031000_rename_org_principal_model_terms.rb`. The creator
  `db/org_principals_migrate/20260521120000_create_operator_social_googles.rb` defines a dependent
  FK/default but no explicit reference seed, and no matching current model was found. Both
  environments have no rows. Current use/ownership and a canonical catalog need a decision; equal
  empty counts do not establish correctness.

## Remaining limits

The current missing-reference list is ready for owner review; **nothing was inserted**. This record
does not claim schema-load reconstruction is repaired, authorize legacy cleanup, or certify other
reference families/databases beyond the original 73. Values of keys, tokens, cookies, personal data,
reference IDs and reference row contents are absent from this evidence.
