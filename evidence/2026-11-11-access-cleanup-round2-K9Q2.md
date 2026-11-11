# Access cleanup round 2 — 2026-11-11

## Result and scope

Completed the authorized second pass of the Access surface cleanup and primary-only reads. This
record supplements the full route/controller inventory and model audit in
[`2026-11-10-surface-hard-reset-M7Q4.md`](2026-11-10-surface-hard-reset-M7Q4.md). The shared
worktree remains uncommitted; no commit was made.

- Full `git rev-parse HEAD`: `281a9e5c539bc0b89b4d37ff5bd6f102976ad4c4`
- Results describe the modified shared worktree; existing unrelated changes were preserved.
- No database was dropped. No model class, migration, schema or structure file was removed or
  changed.
- The user approved preserving cross-repository OIDC client registrations and `.github` is read-only
  for this task. No `.github/**`, `.devcontainer/**`, or encrypted credentials were edited. A
  pre-existing `.devcontainer/compose.yaml` worktree change was left intact.
- `.env*` values were not printed or changed. Only the permitted object-storage variable names were
  removed.

## Owned surfaces and route counts

The final `bin/rails routes` invocation exited 0. These are rendered CLI entries: the main Rails
route set has 271 entries, including six mounted-engine dispatcher rows, and the command expands
those mounts into 72 additional engine entries. The unknown-host fallback is included; Coverband has
a host constraint but its engine emitted zero nested route rows.

| Host group                | Final route entries | Classification                  |
| ------------------------- | ------------------: | ------------------------------- |
| Auth app                  |                 137 | OWN                             |
| Auth org                  |                  46 | OWN                             |
| Visa app                  |                  37 | OWN                             |
| Visa org                  |                  36 | OWN                             |
| Mission                   |                  25 | OWN                             |
| Flipper                   |                   1 | OWN                             |
| Blazer                    |                  32 | OWN                             |
| PgHero                    |                  26 | OWN                             |
| Coverband                 |                   0 | OWN; no engine routes emitted   |
| Swagger                   |                   2 | OWN                             |
| Unknown-host 404 fallback |                   1 | OWN                             |
| **Total**                 |             **343** | **All listed routes are owned** |

Auth app lost only the retired `settings#show` dashboard route since the 344-entry inventory in the
prior report. Visa's OpenID/OAuth endpoints, discovery, JWKS, DBSC and OP-session routes remain.
`config/routes/` contains the Auth, Visa and operator-tool route files; no foreign route namespace
or unowned host route remains. The earlier report's retained controller namespace inventory still
applies, with the Auth app settings dashboard controller removed: the `auth/app/settings` namespace
now contains Apple/Google link controllers and the TOTP ceremony controllers. The top-level
unknown-host controller remains as the fail-closed JSON 404.

## Deletions and cleanup

- Removed foreign frontend roots `src/pages/base`, `core`, `palm` and `warp`, along with their
  unreferenced entrypoints, features, components, styles, assets and gait/Vitest tests. No retained
  Access entrypoint or Inertia page registry referenced those roots. Removed ignored generated
  service-worker registration build artifacts. Vite no longer configures PWA/Workbox output or
  permits `.umaxica.com` hosts.
- Removed the Auth app settings dashboard route, controller, dashboard view, dashboard-only locale
  entries and associated tests. Removed stale tests for the retired Base `/preference` surface and
  stale assertions for deleted Base helper behavior. Updated the retained Apple/Google ceremony
  destinations after the settings dashboard helper disappeared.
- Removed Access's Active Storage/Shrine/S3 integration: the Active Storage engine load,
  `config/storage.yml`, Shrine initializer and uploaders, object-storage library and rake task,
  `shrine`, `aws-sdk-s3`, and storage-only image/vips dependencies. Kept `aws-sdk-sns`. Removed the
  Rails `storage` connection entries, but retained the physical storage database, tables, migrations
  and schema unchanged. Kept `Publishing::MediaFile` because retained model concerns still reference
  it.
- Removed the automatic multi-database read selector initializer and its test support. Replaced
  app/lib read-role calls with primary/writer-role reads. A search of `app/` and `lib/` found zero
  `connected_to(role: :reading)` calls.
- Removed unused frontend helper exports and updated Knip's treatment of Stimulus/Turbo, which are
  still loaded by the retained Rails import map. Added a static test that rejects
  `navigator.serviceWorker.register` in Access source. No Clear-Site-Data behavior was added.
- Added Visa OP session-revocation request coverage for an immediate `/oauth/authorize` request.
  Focused request tests passed.
- Regenerated the ignored Vite output for production, development and Rails browser-E2E modes after
  finding stale pre-reset bundles. All four `public/vite*` manifests now have 54 entries and zero
  foreign-surface entrypoint matches; no worker-registration-like output files remain. These build
  outputs are ignored and were not staged or committed.

Removed `OBJECT_STORAGE_*` names from writable env templates:

```text
OBJECT_STORAGE_ACCESS_KEY_ID
OBJECT_STORAGE_BUCKET_AVATAR
OBJECT_STORAGE_BUCKET_PUBLISHING
OBJECT_STORAGE_ENDPOINT
OBJECT_STORAGE_FORCE_PATH_STYLE
OBJECT_STORAGE_REGION
OBJECT_STORAGE_SECRET_ACCESS_KEY
```

Those names remain referenced only in the locked `.github/workflows/ci.yml`; that file was not
changed. Cross-repository OIDC client URL registrations/readers were retained per the owner's
direction.

The first-pass deleted-file counts and per-file route/controller inventory are recorded in the prior
report, sections 1–2. This pass adds the frontend, settings-dashboard, storage and stale-test
deletions above.

## Model and database report

The detailed static audit in the prior report, section 3, lists each abstract `*Record` database,
each concrete model with one non-model caller path/line, and models found only through other models
or tests. It remains applicable: this pass removed no model class, migration or schema, and all
abstract record bases remain unchanged. The audit counted 28 abstract record bases, 765 concrete
ActiveRecord models and 9 model-path classes without resolved ActiveRecord ancestry.

| Classification      | Abstract `*Record` database keys                                                                                                                                                                          |
| ------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **USED**            | `app_zenith`, `op_base_org`, `op_base_app`, `search`, `occurrence`, `org_zenith`, `primary`, `publishing`, `com_setting`, `avatar`, `org_setting`, `org_signal`, `app_setting`, `chronicle`, `app_signal` |
| **ONLY-VIA-MODELS** | `rp_warp_org`, `rp_core_app`, `rp_core_org`, `rp_warp_app`, `rp_base_org`, `rp_edit_org`, `rp_base_app`, `rp_palm_app`, `rp_tech_org`                                                                     |
| **UNUSED**          | none                                                                                                                                                                                                      |

The storage connection was removed from `config/database.yml`; the physical storage database and its
schema/data remain untouched. `queue` is a framework connection and is not an abstract `*Record`
database. The identity databases are included above as requested.

## Retained items that can look foreign

- External RP redirect URI registrations remain in the Visa OP client registry by explicit owner
  direction; they create no local routes or controllers.
- Apple and Google settings `show`/`edit` actions display linked-identity state. Their `create`
  actions begin provider-link ceremonies and `destroy` unlinks the provider. Those routes and
  controllers remain. The shared `PreferencesBaseController` remains a preference transport base,
  not a dashboard or sign-in ceremony.
- `Publishing::MediaFile` and its two retained model concerns remain because the models still
  reference them, although upload/storage integration was removed. SNS remains for outbound
  notifications; Stimulus and Turbo remain because the retained import map uses them.
- The previously documented Base-prefixed OAuth endpoint concerns, ACME selector/quota helpers,
  Publishing taxonomy values, operator host configuration and unknown-host fallback remain for the
  retained callers/contracts described in section 4 of the prior report.
- The Clear-Site-Data proposal was report-only and was not applied.

## Verification

| Check                             | Result                                                                                                                                                                                                                                                                                                                                                                      |
| --------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `bin/rails zeitwerk:check`        | PASS — eager load completed; `All is good!`                                                                                                                                                                                                                                                                                                                                 |
| `bin/rails routes`                | PASS — 343 rendered owned entries (271 app route-set entries plus 72 engine entries); no `settings#show` route                                                                                                                                                                                                                                                              |
| `bin/rubocop`                     | FAIL — 3,741 files inspected, 221 offenses (183 autocorrectable); cleanup-targeted files passed                                                                                                                                                                                                                                                                             |
| `bundle exec erb_lint --lint-all` | PASS — no errors                                                                                                                                                                                                                                                                                                                                                            |
| `bun run check`                   | FAIL at `openapi:verify`; generated OpenAPI bundles are dirty in this uncommitted worktree. Format, lint, typecheck, Knip, OpenAPI lint and bundle steps completed before that verifier failure.                                                                                                                                                                            |
| Exact `bin/rails test`            | BLOCKED before test execution — test DB preparation reads the protected test database manifest, which still names the removed `storage` Rails connection. Current audit confirmed `test_storage_db` is listed by `POSTGRESQL_TEST_PREPARE_DATABASES` in `.env` and `.env.container.devcontainer`; values were not displayed or changed, per the owner's explicit direction. |
| Diagnostic full Rails suite       | FAIL with 12,304 runs, 89,436 assertions, 29 failures, 37 errors, 0 skips. It used the repository CI test manifest in the subprocess, without editing `.env*`.                                                                                                                                                                                                              |
| `git diff --check`                | PASS                                                                                                                                                                                                                                                                                                                                                                        |
| `bundle check`                    | PASS                                                                                                                                                                                                                                                                                                                                                                        |
| `bin/rails architecture:baseline` | PASS                                                                                                                                                                                                                                                                                                                                                                        |
| Targeted cleanup tests            | PASS — 141 runs, 2,872 assertions, 0 failures/errors; targeted settings route tests also passed (10 runs, 362 assertions); SNS tests passed (6 runs, 14 assertions).                                                                                                                                                                                                        |
| Vite builds                       | PASS — production (`bun run build`), development and Rails browser-E2E builds completed; rebuilt manifests have no foreign-surface entrypoint keys.                                                                                                                                                                                                                         |

After the full check, `bun run openapi:bundle` was run again: it exited 0 and left both bundled
OpenAPI files byte-identical. The `openapi:verify` failure is the verifier's expected clean-worktree
diff check against these intentionally changed, uncommitted bundles.

### Full-suite failures retained from the task baseline

The saved pre-Round-2 baseline run had 12,357 runs, 89,536 assertions, 38 failures and 38 errors.
Comparison of test identifiers found no new failure or error identifiers: 9 baseline failures and 1
baseline error resolved; the remaining 29 failures and 37 errors are all present in that baseline.
The test count difference reflects the removed stale surface tests and changed test set. The
remaining pre-existing failure identifiers are:

```text
Wua6StandbySupportRevocationScreenTest#test_ORG_read-only_owner_screens_deny_Standby_and_allow_Normal_with_fresh_matching_Step-Up
EffectiveEntryIntentTest#test_app_create_admission_refuses_the_other_intent_at_continuation_without_consumption
EffectiveEntryIntentTest#test_app_create_admission_refuses_the_other_intent_at_redemption_without_consumption
EffectiveEntryIntentTest#test_app_ordinary_admission_refuses_the_other_intent_at_redemption_without_consumption
EffectiveEntryIntentTest#test_app_ordinary_admission_refuses_the_other_intent_at_continuation_without_consumption
JumpRtIssuerJwksAuthorityTest#test_canonical_Jump_issuers_sign_RT_and_the_routing_surfaces_publish_the_exact_signing_key
Security::Invariants::MountedEngineInvariantTest#test_no_unauthenticated_admin_engine_path_is_routable_outside_development
OidcEndSessionRequestTest#test_rejects_post_logout_redirect_uri_registered_for_another_realm
Auth::App::Sign::Up::Check::Email::BirthdatesControllerTest#test_the_email_OTP_page_ends_sign-up_through_its_DELETE_cancellation
AssociationContractTest#test_associations_declaring_inverse_of_resolve_to_an_existing_inverse_association
AuthRegionContractTest#test_every_generated_link_on_an_entry_page_carries_the_requested_region
Visa::Org::SensitiveAdmissionApiCoverageTest#test_ORG_admission_creation_reaches_validation_with_an_authenticated_registered_client
Visa::Org::SensitiveAdmissionApiCoverageTest#test_ORG_browser_confirmation_rejects_missing_binding_evidence_without_changing_the_admission
AuthCeremonyAdmissionBoundaryTest#test_direct_sign-up_contact_POST_cannot_create_an_email_or_telephone_OTP_or_actor_before_confirmed_redemption
IdentityStepUpTotpDeviceConcurrencyTest#test_Ticket_evidence_commits_before_a_waiting_device_revocation
AuthApiV0PreferenceEndpointsTest#test_app_theme_mutation_is_refused_without_creating_Preference_state
Auth::App::SignInAdmissionTest#test_Auth_APP_sign-in_state_is_issued_in_a_secure_host-only_purpose_cookie
Auth::App::SignInAdmissionTest#test_a_tampered_sign-in_purpose_cookie_shows_restart_guidance_without_changing_cookies
Auth::BaseTest#test_JwtConfiguration.audiences_rejects_missing_blank_and_overlapping_values
ModelTableFixtureConsistencyTest#test_application_record_table_names_follow_model_tableize_convention
AppleAuthTest#test_callback_initializes_preference_timezone_options_when_missing
Auth::App::Sign::Up::EmailsControllerTest#test_email_signup_checkpoint_cancel_stops_the_signup_path
OpenapiPreferencesContractTest#test_Auth_app_preference_endpoints_conform_to_the_app_description
OpenapiPreferencesContractTest#test_Auth_org_preference_endpoints_conform_to_the_org_description
Concerns::ApplicationControllerCommonPatternsTest#test_app_surface_lifecycle_controllers_reflect_timezone
EnforcementReconciliationJobTest#test_ends_an_active_case_whose_approved_appeal_did_not_finish_ending_it
RedirectTargetUsageTest#test_allow_other_host_true_is_limited_to_reviewed_Jump_and_protocol_handoff_boundaries
EnforcementReconciliationJobTest#test_completes_the_end_audit_for_an_approved_appeal_whose_case_already_ended
ObjectPlacementTest#test_every_file_names_its_own_role
```

The remaining 37 errors are also all baseline identifiers; one baseline error resolved:

```text
Auth::Org::ApplicationControllerTest#test_authenticate_operator!_allows_access_when_operator_is_logged_in
IdentityStepUpCeremonyAcmeTransactionTest#test_transaction_scopes_and_purger_retain_recent_records_and_purge_old_records
IdentityStepUpCeremonyAcmeTransactionTest#test_grant_issuance_creates_durable_step_up_transaction_and_valid_grant
IdentitySocialCeremonyContractTest#test_a_valid_grant_serializes_and_verifies
IdentitySocialCeremonyContractTest#test_a_login_grant_carries_no_provider_token_claims
IdentitySocialCeremonyContractTest#test_signature_verification_rejects_wrong_key_and_tampering
IdentitySocialCeremonyContractTest#test_verified_grant_decoding_rejects_a_payload_changed_after_signing
CloudflareTurnstileVisiblePartialTest#test_renders_optional_ceremony_binding_attributes
CloudflareTurnstileVisiblePartialTest#test_omits_ceremony_binding_attributes_by_default
NotNullColumnNilValidationContractTest#test_RpBaseOrgStepUpState_NOT_NULL_columns_reject_nil_before_SQL
Security::Invariants::CookieSecurityInvariantTest#test_shared_preference_JWT_and_display_cookies_are_secure_and_scoped_to_their_realm_domain
NotNullColumnNilValidationContractTest#test_RpStepUpState_NOT_NULL_columns_reject_nil_before_SQL
IdentityPasskeyCeremonyContractTest#test_signature_verification_rejects_wrong_key_and_tampering
IdentityPasskeyCeremonyContractTest#test_valid_grant_and_result_serialize_and_verify
CloudflareTurnstileStealthPartialTest#test_renders_widget_controls_without_loading_the_api_script
RetentionPurgeJobTest#test_generic_retention_preserves_com_preferences_and_their_audit_history
IdentityStepUpCeremonyContractTest#test_signature_verification_rejects_wrong_key_and_payload_tampering
IdentityStepUpCeremonyContractTest#test_valid_explicit_grant_and_result_serialize_and_verify
IdentityStepUpCeremonyAalTest#test_the_no-AAL_storage_label_decodes_as_no_legacy_requirement
AcceptanceWu02ClientAssertionAudienceTest#test_A02-5:_token_endpoint_rejects_retired_www_client_assertion_audiences_in_every_realm
SignUpOtpDeliveryIssuerTest#test_app_email_issuer_refuses_replacement_of_a_committed_proof_without_claiming_delivery
SignUpOtpDeliveryIssuerTest#test_app_telephone_issuer_refuses_replacement_of_a_committed_proof_without_claiming_delivery
SignUpCancellationTest#test_replayed_cancel_reruns_cleanup_when_previous_cleanup_did_not_finish
ErbLayoutPreferenceControlsTest#test_Auth_layouts_expose_their_same-origin_preference_endpoints
CspViolationReportsControllerTest#test_post_without_csrf_token_returns_no_content
CspViolationReportsControllerTest#test_ordinary_state-changing_endpoint_still_rejects_tokenless_post_when_forgery_protection_is_enabled
RootRevokeOthersConcurrentLoginTest#test_A44-10_revoke-others_snapshots_existing_roots_before_a_concurrent_Root_login_commits
CspViolationReportsControllerTest#test_accepts_CSP_report_with_Origin_null_when_forgery_protection_is_enabled
PasskeyAuthenticationResubmissionHttpTest#test_two_concurrent_HTTP_resubmissions_admit_at_most_one_authentication_and_preserve_its_Auth_session
IdentityTotpNameCommitOrderTest#test_concurrent_TOTP_renames_can_reuse_one_Step-Up_event
OutboundSensitivePayloadTest#test_registration_OTP_SMS_uses_version_four_and_preserves_its_original_ceremony_tuple
Outbound::SmsDeliveryJobTest#test_retired_corporate_OTP_deliveries_are_reported_without_sending
OtpVerificationFailureBudgetTest#test_success_creates_no_key_and_signup_exhaustion_cannot_exhaust_other_scopes
ExternalAuthenticationAuthenticationMethodLockPolicyTest#test_is_not_locked_once_the_case_has_ended
BannerPartialTest#test_renders_body_without_title_heading_when_title_is_blank
BannerPartialTest#test_renders_title_and_body_when_title_is_present
CredentialRegistrationOtpSessionValueTest#test_registration_session_encodes_the_original_Root_and_realm_channel_transaction_bound_browser_digest
```
