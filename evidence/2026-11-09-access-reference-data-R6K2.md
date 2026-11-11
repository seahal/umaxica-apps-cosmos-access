# Access authorization reference-data diagnosis

Date: 2026-11-09 UTC. Revision: `281a9e5c539bc0b89b4d37ff5bd6f102976ad4c4`. The existing worktree
contains extensive unrelated tracked and untracked changes, including Access implementation and the
source acceptance report. Observations describe that worktree, not pristine HEAD. This task changes
only this evidence record so far.

## Outcome

The immediate authorization failure is caused by absent development reference rows. Both
authorization transaction status tables contain zero rows; all four IDs required by each owning
migration are absent. Both corresponding migration versions are recorded as applied. Both test
tables contain all four required rows (missing count zero).

`OidcAuthorizationTransactionable.authorization_transaction_attributes` explicitly assigns the
pending status ID. Both concrete transaction models require the `status` association; the concern
also validates status ID presence and membership. A nonempty ID cannot resolve a required
association when its reference table is empty. No validation was weakened and no missing-status
writer was identified on this creation path.

This matches the known schema-load failure mechanism described in
`research/implementation/2026-10-13-reference-data-after-schema-load.md`: dumps include migration
markers but omit reference rows. The actual command that created the current development databases
was not observed, so reconstruction history is an inference, not a confirmed event.

## Read-only method

Used direct `psql` connections to the local Dev Container PostgreSQL host `primary`, with
`PGOPTIONS='-c default_transaction_read_only=on -c statement_timeout=15000'`, `-XAt`, and
`ON_ERROR_STOP`-equivalent subprocess exit checking. Each query was a SELECT. Rails was not booted:
`config/initializers/preference_reference_defaults.rb` can insert rows during development startup.
No database writes, service changes, resets, migrations, HTTP requests or external calls were made.
No row values, credentials, URLs, cookies, tokens or request parameters are retained here.

Inspected development/test writer databases for `op_base_app`, `op_base_org`, `app_zenith`, and
`org_zenith`. Enumerated public tables ending in statuses, states, kinds, methods, modes,
visibilities, causes or scopes; counted rows. Excluded OAuth callback and DPoP proof state tables
from the reference inventory after reading their models: these hold runtime records, not fixed
catalogs, and zero is not evidence of missing reference data.

Counts below are exact at query time; test databases may be affected by other work. Nonzero counts
establish presence only, not completeness or correctness. Exact required-ID comparison was performed
for both authorization status tables against their owning migration catalogs. Other catalogs have
not all been reconciled against their full migration histories; this inventory is bounded to the
four named database owners and suffix selection.

## Inventory

| Owner       | Reference table                                    | Development count / presence | Test count / presence |
| ----------- | -------------------------------------------------- | ---------------------------- | --------------------- |
| app_zenith  | `client_email_statuses`                            | 7 / present                  | 7 / present           |
| app_zenith  | `client_identity_states`                           | 4 / present                  | 4 / present           |
| app_zenith  | `client_mfa_statuses`                              | 3 / present                  | 3 / present           |
| app_zenith  | `client_passkey_statuses`                          | 5 / present                  | 5 / present           |
| app_zenith  | `client_preference_statuses`                       | 0 / absent                   | 2 / present           |
| app_zenith  | `client_privacy_request_statuses`                  | 0 / absent                   | 9 / present           |
| app_zenith  | `client_processor_erasure_notification_statuses`   | 0 / absent                   | 5 / present           |
| app_zenith  | `client_profile_statuses`                          | 0 / absent                   | 1 / present           |
| app_zenith  | `client_registration_completion_methods`           | 0 / absent                   | 4 / present           |
| app_zenith  | `client_retention_hold_statuses`                   | 0 / absent                   | 3 / present           |
| app_zenith  | `client_security_modes`                            | 2 / present                  | 2 / present           |
| app_zenith  | `client_statuses`                                  | 13 / present                 | 12 / present          |
| app_zenith  | `client_telephone_statuses`                        | 8 / present                  | 8 / present           |
| app_zenith  | `client_totp_credential_statuses`                  | 5 / present                  | 5 / present           |
| app_zenith  | `client_visibilities`                              | 4 / present                  | 4 / present           |
| app_zenith  | `client_withdrawal_flow_statuses`                  | 0 / absent                   | 7 / present           |
| app_zenith  | `legacy_replaced_client_statuses`                  | 0 / absent                   | 5 / present           |
| app_zenith  | `member_statuses`                                  | 5 / present                  | 5 / present           |
| app_zenith  | `persona_membership_kinds`                         | 4 / present                  | 4 / present           |
| app_zenith  | `persona_membership_states`                        | 6 / present                  | 6 / present           |
| op_base_app | `client_auth_admission_binding_statuses`           | 0 / absent                   | 6 / present           |
| op_base_app | `client_auth_ceremony_session_statuses`            | 0 / absent                   | 8 / present           |
| op_base_app | `client_oidc_authorization_transaction_statuses`   | 0 / absent                   | 4 / present           |
| op_base_app | `client_session_limit_resolution_states`           | 5 / present                  | 5 / present           |
| op_base_app | `client_sign_in_flow_states`                       | 14 / present                 | 14 / present          |
| op_base_app | `client_sign_up_flow_cleanup_statuses`             | 5 / present                  | 5 / present           |
| op_base_app | `client_sign_up_flow_statuses`                     | 15 / present                 | 15 / present          |
| op_base_app | `client_step_up_audit_outbox_delivery_states`      | 0 / absent                   | 2 / present           |
| op_base_app | `client_step_up_context_states`                    | 0 / absent                   | 5 / present           |
| op_base_app | `client_token_binding_methods`                     | 3 / present                  | 3 / present           |
| op_base_app | `client_token_dbsc_statuses`                       | 5 / present                  | 5 / present           |
| op_base_app | `client_token_kinds`                               | 3 / present                  | 3 / present           |
| op_base_app | `client_token_statuses`                            | 5 / present                  | 5 / present           |
| op_base_app | `op_app_authority_stop_causes`                     | 9 / present                  | 9 / present           |
| op_base_app | `op_app_authority_stop_participant_statuses`       | 4 / present                  | 4 / present           |
| op_base_app | `op_app_authority_stop_scopes`                     | 3 / present                  | 3 / present           |
| op_base_org | `op_org_authority_stop_causes`                     | 9 / present                  | 9 / present           |
| op_base_org | `op_org_authority_stop_participant_statuses`       | 4 / present                  | 4 / present           |
| op_base_org | `op_org_authority_stop_scopes`                     | 3 / present                  | 3 / present           |
| op_base_org | `operator_auth_admission_binding_statuses`         | 0 / absent                   | 6 / present           |
| op_base_org | `operator_auth_ceremony_session_statuses`          | 0 / absent                   | 8 / present           |
| op_base_org | `operator_oidc_authorization_transaction_statuses` | 0 / absent                   | 4 / present           |
| op_base_org | `operator_session_limit_resolution_states`         | 5 / present                  | 5 / present           |
| op_base_org | `operator_sign_in_flow_states`                     | 14 / present                 | 14 / present          |
| op_base_org | `operator_sign_up_flow_statuses`                   | 9 / present                  | 9 / present           |
| op_base_org | `operator_step_up_audit_outbox_delivery_states`    | 0 / absent                   | 2 / present           |
| op_base_org | `operator_step_up_context_states`                  | 0 / absent                   | 5 / present           |
| op_base_org | `operator_token_binding_methods`                   | 3 / present                  | 3 / present           |
| op_base_org | `operator_token_dbsc_statuses`                     | 5 / present                  | 5 / present           |
| op_base_org | `operator_token_kinds`                             | 3 / present                  | 3 / present           |
| op_base_org | `operator_token_statuses`                          | 5 / present                  | 5 / present           |
| org_zenith  | `agent_membership_kinds`                           | 4 / present                  | 4 / present           |
| org_zenith  | `agent_membership_states`                          | 6 / present                  | 6 / present           |
| org_zenith  | `department_statuses`                              | 4 / present                  | 4 / present           |
| org_zenith  | `division_statuses`                                | 4 / present                  | 1 / present           |
| org_zenith  | `operator_email_statuses`                          | 7 / present                  | 7 / present           |
| org_zenith  | `operator_entra_identity_states`                   | 4 / present                  | 0 / absent            |
| org_zenith  | `operator_google_identity_statuses`                | 0 / absent                   | 0 / absent            |
| org_zenith  | `operator_identity_states`                         | 4 / present                  | 4 / present           |
| org_zenith  | `operator_mfa_statuses`                            | 3 / present                  | 3 / present           |
| org_zenith  | `operator_passkey_statuses`                        | 2 / present                  | 2 / present           |
| org_zenith  | `operator_preference_statuses`                     | 0 / absent                   | 2 / present           |
| org_zenith  | `operator_secret_credential_kinds`                 | 2 / present                  | 1 / present           |
| org_zenith  | `operator_secret_credential_statuses`              | 5 / present                  | 5 / present           |
| org_zenith  | `operator_security_modes`                          | 2 / present                  | 2 / present           |
| org_zenith  | `operator_statuses`                                | 3 / present                  | 3 / present           |
| org_zenith  | `operator_telephone_statuses`                      | 7 / present                  | 7 / present           |
| org_zenith  | `operator_visibilities`                            | 4 / present                  | 4 / present           |
| org_zenith  | `operator_workspace_account_statuses`              | 2 / present                  | 2 / present           |
| org_zenith  | `organization_entra_connection_states`             | 4 / present                  | 0 / absent            |
| org_zenith  | `organization_statuses`                            | 1 / present                  | 1 / present           |
| org_zenith  | `staff_identity_statuses`                          | 0 / absent                   | 3 / present           |
| org_zenith  | `workspace_statuses`                               | 0 / absent                   | 2 / present           |

## Proposed bounded repair — NOT executed; owner approval required

Migrations own reference catalogs. `db/seeds.rb` replays a hand-listed subset through idempotent
fixed-ID inserts, but omits authorization status, admission binding status and ceremony session
status catalogs. Running `db:seed` as it stands does not repair these six tables and additionally
writes sample identities, flags and publishing data. Rerunning complete migrations would attempt
DDL/backfills and is unsuitable for an existing database. No existing selective recovery task was
found in `lib/tasks/`.

Propose replaying only the canonical fixed catalog inserts, using the same
`INSERT ... ON CONFLICT (id) DO NOTHING` mechanism already used by seeds, through direct SQL
connections so Rails startup cannot add unrelated reference rows. Derive the IDs from the owning
migration constants and cross-check the current model DEFAULTS; do not execute migration up/change
methods. No schema, migration markers, existing rows, identities or flags would be changed.

| Development database owner | Target table                                       | Missing rows to insert |
| -------------------------- | -------------------------------------------------- | ---------------------- |
| op_base_app                | `client_oidc_authorization_transaction_statuses`   | 4                      |
| op_base_org                | `operator_oidc_authorization_transaction_statuses` | 4                      |
| op_base_app                | `client_auth_admission_binding_statuses`           | 6                      |
| op_base_org                | `operator_auth_admission_binding_statuses`         | 6                      |
| op_base_app                | `client_auth_ceremony_session_statuses`            | 8                      |
| op_base_org                | `operator_auth_ceremony_session_statuses`          | 8                      |

Total proposed: 36 fixed reference rows in six tables, across two development databases. The
authorization writer issues an admission handoff after creating the parent transaction, and Auth
uses the ceremony session catalog, so repairing only the first eight rows would leave adjacent
prerequisite failures. Other empty reference tables remain separately inventoried above; no blanket
repair is proposed or authorized.

Canonical migration sources:

- `db/op_base_app_migrate/20261101041000_add_state_reference_to_client_oidc_authorization_transactions.rb`
- `db/op_base_org_migrate/20261101041003_add_state_reference_to_operator_oidc_authorization_transactions.rb`
- `db/op_base_app_migrate/20261101031705_add_status_to_client_auth_admission_bindings.rb`
- `db/op_base_org_migrate/20261101031710_add_status_to_operator_auth_admission_bindings.rb`
- `db/op_base_app_migrate/20261101034328_add_status_to_client_auth_ceremony_sessions.rb`
- `db/op_base_org_migrate/20261101034343_add_status_to_operator_auth_ceremony_sessions.rb`

Execution after approval: re-count missing catalogs, begin a transaction on each explicitly named
development writer, insert only missing fixed IDs with conflict-ignore semantics, verify exact
catalog coverage and insertion counts before committing each writer. The two databases do not share
an atomic transaction; record partial completion if one fails and resume idempotently. Before commit
a failure rolls back that writer. After commit retain the required reference rows; do not delete
them as recovery. No data deletion, database rebuild or reset is part of this repair.

## Remaining acceptance / approval boundary

Owner approval for the above development persistence change is pending. No repair is claimed. After
approval and insertion, verify a valid unauthenticated Visa App and Org authorization request
redirects to the configured Auth sign-in entry, without following external destinations or retaining
raw Location/request values. That request can create authorization/admission records and local
handoff/cache state; it must be included in the authorized development verification. Auth redirect
behavior remains unverified. No behavior tests were added or executed because no application code
was changed. No commit was created.
