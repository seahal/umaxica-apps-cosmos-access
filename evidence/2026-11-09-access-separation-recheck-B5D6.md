# Access Separation Recheck

Date: 2026-11-09

## Scope and repository state

This recheck follows the Access surface cleanup, the Rails revision pin, GUID surface retirement,
and Neon production database configuration removal. It records the current dirty worktree; no commit
was created.

- HEAD: `281a9e5c539bc0b89b4d37ff5bd6f102976ad4c4`.
- Uncommitted changes: yes; this worktree contains extensive existing changes. Results apply to that
  worktree.
- Test commands used the configured test database only. No database setup, reset, create, or delete
  command was run.
- No container operation or external service write was performed. No `.env*` file was read or
  changed.

## Verification

- `PARALLEL_WORKERS=1 bin/rails test test/security`: **144 runs, 821 assertions, 0 failures, 0
  errors, 0 skips**.
- `PARALLEL_WORKERS=1 bin/rails test`: **14,882 runs, 115,444 assertions, 255 failures, 21 errors, 0
  skips**.
- Focused social-flow rerun (four files): **38 runs, 329 assertions, 0 failures, 0 errors, 0
  skips**. The changed social sign-in/sign-up paths begin through a Visa OIDC authorization entry
  and no longer depend on Base `/sign` forms.
- `bin/rubocop`: **4,652 files inspected, no offenses**.
- `bin/brakeman --quiet --no-pager --exit-on-warn --exit-on-error`: **0 errors, 0 security
  warnings**.
- `git diff --check`: passed.
- `git grep -iw neon -- config app lib test`: 0 matches (grep exit status 1 means no matches).

## Split-attributable error audit

The full run produced 21 error blocks. None are `NameError`, missing-route `NoMethodError`, or
routing errors, and none point to a removed Base/Core/Edit/etc. route, controller, or view. Under
the requested criterion (errors caused by references to removed routes/controllers), the count is
**0**. The individual baseline failure IDs from before the split were not retained, so this
classification does not claim that every remaining error is historically pre-existing.

Remaining errors (test identifier, exception family, first repository frame):

- `AvatarRegistryTransferFailureTest#test_org_to_org_transfer_rolls_back_a_destination_write_failure_and_retries_once:`
  — `AvatarOwnershipTransfers`;
  `app/operations/avatar_ownership_transfers/operation.rb:16:in 'AvatarOwnershipTransfers::Operation#validate_step_up_context!'`.
- `AvatarRegistryTransferFailureTest#test_app_to_app_transfer_rolls_back_a_destination_write_failure_and_retries_once:`
  — `AvatarOwnershipTransfers`;
  `app/operations/avatar_ownership_transfers/operation.rb:16:in 'AvatarOwnershipTransfers::Operation#validate_step_up_context!'`.
- `AvatarRegistryTransferFailureTest#test_org_to_app_transfer_rolls_back_a_destination_write_failure_and_retries_once:`
  — `AvatarOwnershipTransfers`;
  `app/operations/avatar_ownership_transfers/operation.rb:16:in 'AvatarOwnershipTransfers::Operation#validate_step_up_context!'`.
- `AvatarRegistryTransferFailureTest#test_app_to_org_transfer_rolls_back_a_destination_write_failure_and_retries_once:`
  — `AvatarOwnershipTransfers`;
  `app/operations/avatar_ownership_transfers/operation.rb:16:in 'AvatarOwnershipTransfers::Operation#validate_step_up_context!'`.
- `ExternalAuthenticationAuthenticationMethodLockPolicyTest#test_is_not_locked_once_the_case_has_ended:`
  — `ArgumentError`;
  `app/operations/enforcement_case_end_operation.rb:166:in 'EnforcementCaseEndOperation#validate_step_up_pair!'`.
- `OutboundSensitivePayloadTest#test_registration_OTP_SMS_uses_version_four_and_preserves_its_original_ceremony_tuple:`
  — `ArgumentError`;
  `app/values/telephone_credential_registration_otp_delivery_binding_value.rb:17:in 'TelephoneCredentialRegistrationOtpDeliveryBindingValue.for_sms'`.
- `SignUpCancellationTest#test_replayed_cancel_reruns_cleanup_when_previous_cleanup_did_not_finish:`
  — `ActiveRecord`;
  `app/models/client_sign_up_flow.rb:183:in 'block (2 levels) in ClientSignUpFlow#with_cycle_lock'`.
- `AvatarOwnershipCutoverOperationTest#test_blocks_cutover_when_an_existing_Group_is_omitted_from_the_bounded_selection:`
  — `ArgumentError`;
  `app/operations/avatar_ownership_cutover_operation.rb:74:in 'AvatarOwnershipCutoverOperation.validate_arguments!'`.
- `AvatarOwnershipCutoverOperationTest#test_requires_explicit_writer_quiescence_and_never_establishes_marker_in_dry_run:`
  — `ArgumentError`;
  `app/operations/avatar_ownership_cutover_operation.rb:74:in 'AvatarOwnershipCutoverOperation.validate_arguments!'`.
- `AvatarOwnershipCutoverOperationTest#test_establishes_the_singleton_marker_only_after_a_clean_inventory_and_is_idempotent:`
  — `ArgumentError`;
  `app/operations/avatar_ownership_cutover_operation.rb:74:in 'AvatarOwnershipCutoverOperation.validate_arguments!'`.
- `RootRevokeOthersConcurrentLoginTest#test_A44-10_revoke-others_snapshots_existing_roots_before_a_concurrent_Root_login_commits:`
  — `ArgumentError`;
  `app/operations/authentication_other_sessions_revoker.rb:20:in 'AuthenticationOtherSessionsRevoker#initialize'`.
- `OtpVerificationFailureBudgetTest#test_success_creates_no_key_and_signup_exhaustion_cannot_exhaust_other_scopes:`
  — `ArgumentError`;
  `app/models/email_otp_verification_failure_budget.rb:39:in 'EmailOtpVerificationFailureBudget#verify!'`.
- `SignUpOtpDeliveryIssuerTest#test_app_email_issuer_refuses_replacement_of_a_committed_proof_without_claiming_delivery:`
  — `EmailSignUpOtpDeliveryIssuer`;
  `app/operations/email_sign_up_otp_delivery_issuer.rb:27:in 'EmailSignUpOtpDeliveryIssuer.call'`.
- `SignUpOtpDeliveryIssuerTest#test_app_telephone_issuer_refuses_replacement_of_a_committed_proof_without_claiming_delivery:`
  — `TelephoneSignUpOtpDeliveryIssuer`;
  `app/operations/telephone_sign_up_otp_delivery_issuer.rb:26:in 'TelephoneSignUpOtpDeliveryIssuer.call'`.
- `Auth::Org::ApplicationControllerTest#test_authenticate_operator!_allows_access_when_operator_is_logged_in:`
  — `ArgumentError`;
  `app/values/actor_values_context.rb:138:in 'ActorValuesContext#validate_axis!'`.
- `IdentityTotpNameCommitOrderTest#test_concurrent_TOTP_renames_can_reuse_one_Step-Up_event:` —
  `IdentityTotpNameCommitter`;
  `app/operations/identity_totp_name_committer.rb:93:in 'IdentityTotpNameCommitter#perform_commit!'`.
- `ComPreferenceWritePurgeTest#test_collection_before_reset_leaves_the_new_preference_independent_of_the_removed_row:`
  — `Timeout`;
  `test/concurrency/com_preference_write_purge_test.rb:121:in 'ComPreferenceWritePurgeTest#wait_for_advisory_waiter!'`.
- `ComPreferenceWritePurgeTest#test_collection_before_save_leaves_the_new_preference_independent_of_the_removed_row:`
  — `Timeout`;
  `test/concurrency/com_preference_write_purge_test.rb:121:in 'ComPreferenceWritePurgeTest#wait_for_advisory_waiter!'`.
- `CredentialRegistrationOtpSessionValueTest#test_registration_session_encodes_the_original_Root_and_realm_channel_transaction_bound_browser_digest:`
  — `ArgumentError`;
  `app/values/credential_registration_otp_session_value.rb:10:in 'CredentialRegistrationOtpSessionValue.for'`.
- `Outbound::SmsDeliveryJobTest#test_retired_corporate_OTP_deliveries_are_reported_without_sending:`
  — `ArgumentError`;
  `app/values/telephone_credential_registration_otp_delivery_binding_value.rb:17:in 'TelephoneCredentialRegistrationOtpDeliveryBindingValue.for_sms'`.
- `PasskeyAuthenticationResubmissionHttpTest#test_two_concurrent_HTTP_resubmissions_admit_at_most_one_authentication_and_preserve_its_Auth_session:`
  — `RuntimeError`;
  `test/concurrency/passkey_authentication_resubmission_http_test.rb:61:in 'block in <class:PasskeyAuthenticationResubmissionHttpTest>'`.

## Remaining failures (not modified)

The 255 failure identifiers below are preserved as an inventory. They were not changed in response
to this run. Because individual pre-split failure IDs are unavailable, this list does not assign
each failure to the decomposition or to the prior baseline.

- `test/config/routing_entrypoints_test.rb` (1):
  `RoutingEntrypointsTest#test_global_routing_entrypoints_are_loaded`.
- `test/contracts/openapi_core_session_contract_test.rb` (6):
  `OpenapiCoreSessionContractTest#test_an_anonymous_session_summary_conforms`;
  `OpenapiCoreSessionContractTest#test_a_refusal_of_the_wrong_credential_transport_conforms`;
  `OpenapiCoreSessionContractTest#test_a_disabled_boundary_answers_a_conforming_problem_document`;
  `OpenapiCoreSessionContractTest#test_a_rotation_without_a_csrf_token_conforms`;
  `OpenapiCoreSessionContractTest#test_a_successful_credential_rotation_conforms`;
  `OpenapiCoreSessionContractTest#test_an_authenticated_session_summary_conforms`.
- `test/contracts/openapi_health_contract_test.rb` (10):
  `OpenapiHealthContractTest#test_GET_/api/v0/revision.json_conforms_to_the_com_description`;
  `OpenapiHealthContractTest#test_GET_/api/v0/health.json_conforms_to_the_com_description`;
  `OpenapiHealthContractTest#test_GET_/api/v0/health.json_conforms_to_the_org_description`;
  `OpenapiHealthContractTest#test_the_text_probes_are_not_JSON_endpoints`;
  `OpenapiHealthContractTest#test_GET_/api/v0/health.json_refuses_a_non-JSON_Accept_with_an_undescribed_406_on_com`;
  `OpenapiHealthContractTest#test_GET_/api/v0/revision.json_conforms_to_the_org_description`;
  `OpenapiHealthContractTest#test_GET_/api/v0/health.json_conforms_to_the_app_description`;
  `OpenapiHealthContractTest#test_GET_/api/v0/revision.json_conforms_to_the_app_description`;
  `OpenapiHealthContractTest#test_GET_/api/v0/health.json_refuses_a_non-JSON_Accept_with_an_undescribed_406_on_app`;
  `OpenapiHealthContractTest#test_GET_/api/v0/health.json_refuses_a_non-JSON_Accept_with_an_undescribed_406_on_org`.
- `test/contracts/openapi_route_coverage_test.rb` (3):
  `OpenapiRouteCoverageTest#test_edit_org_operational_API_routes_are_covered_by_the_org_description`;
  `OpenapiRouteCoverageTest#test_no_operation_in_a_surface_description_is_absent_from_the_router`;
  `OpenapiRouteCoverageTest#test_no_route_the_router_serves_is_missing_from_its_surface_description`.
- `test/controllers/auth/api_v0_preference_endpoints_test.rb` (1):
  `AuthApiV0PreferenceEndpointsTest#test_app_theme_mutation_is_refused_without_creating_Preference_state`.
- `test/controllers/auth/app/settings/apples_controller_test.rb` (1):
  `Auth::App::Settings::ApplesControllerTest#test_show_redirects_when_not_logged_in`.
- `test/controllers/auth/app/sign/up/check/email/birthdates_controller_test.rb` (1):
  `Auth::App::Sign::Up::Check::Email::BirthdatesControllerTest#test_the_email_OTP_page_ends_sign-up_through_its_DELETE_cancellation`.
- `test/controllers/auth/app/sign_in_admission_test.rb` (2):
  `Auth::App::SignInAdmissionTest#test_a_tampered_sign-in_purpose_cookie_shows_restart_guidance_without_changing_cookies`;
  `Auth::App::SignInAdmissionTest#test_Auth_APP_sign-in_state_is_issued_in_a_secure_host-only_purpose_cookie`.
- `test/controllers/auth/app/up/emails_controller_test.rb` (1):
  `Auth::App::Sign::Up::EmailsControllerTest#test_email_signup_checkpoint_cancel_stops_the_signup_path`.
- `test/controllers/auth/ceremony_admission_boundary_test.rb` (1):
  `AuthCeremonyAdmissionBoundaryTest#test_direct_sign-up_contact_POST_cannot_create_an_email_or_telephone_OTP_or_actor_before_confirmed_redemption`.
- `test/controllers/auth/effective_entry_intent_test.rb` (4):
  `EffectiveEntryIntentTest#test_app_ordinary_admission_refuses_the_other_intent_at_redemption_without_consumption`;
  `EffectiveEntryIntentTest#test_app_create_admission_refuses_the_other_intent_at_continuation_without_consumption`;
  `EffectiveEntryIntentTest#test_app_ordinary_admission_refuses_the_other_intent_at_continuation_without_consumption`;
  `EffectiveEntryIntentTest#test_app_create_admission_refuses_the_other_intent_at_redemption_without_consumption`.
- `test/controllers/auth/org/omniauth/omniauth_callbacks_controller_test.rb` (1):
  `Auth::Org::Omniauth::OmniauthCallbacksControllerTest#test_app-surface_OmniAuth_providers_are_rejected_on_the_org_host`.
- `test/controllers/concerns/application_controller_common_patterns_test.rb` (1):
  `Concerns::ApplicationControllerCommonPatternsTest#test_app_surface_lifecycle_controllers_reflect_timezone`.
- `test/controllers/concerns/auth/base_test.rb` (1):
  `Auth::BaseTest#test_JwtConfiguration.audiences_rejects_missing_blank_and_overlapping_values`.
- `test/controllers/concerns/preference_write_boundary_test.rb` (1):
  `PreferenceWriteBoundaryTest#test_static_writer_authorization_refuses_cross-realm_and_non-preference_callers`.
- `test/controllers/content_surface_browser_gate_test.rb` (5):
  `ContentSurfaceBrowserGateTest#test_the_machine_health_json_endpoint_is_not_gated_on_browser_version`;
  `ContentSurfaceBrowserGateTest#test_the_entries_api_answers_an_outdated_browser_with_json,_not_an_html_gate_page`;
  `ContentSurfaceBrowserGateTest#test_health_probes_answer_an_outdated_user_agent_rather_than_gating_them`;
  `ContentSurfaceBrowserGateTest#test_the_html_landing_page_still_gates_outdated_browsers`;
  `ContentSurfaceBrowserGateTest#test_the_html_landing_page_still_serves_a_modern_browser`.
- `test/controllers/pwa_endpoints_test.rb` (8):
  `PwaEndpointsTest#test_the_offline_retry_control_is_a_GET_form_that_targets_the_failed_path,_not_its_directory`;
  `PwaEndpointsTest#test_every_Rails-rendered_origin_serves_the_offline_document_without_authentication`;
  `PwaEndpointsTest#test_every_Rails-rendered_origin_serves_the_service_worker_script`;
  `PwaEndpointsTest#test_worker-src_permits_same-origin_workers_on_every_surface`;
  `PwaEndpointsTest#test_the_content_security_policy_relaxation_is_scoped_to_the_PWA_endpoints`;
  `PwaEndpointsTest#test_the_service_worker_caches_the_offline_document_and_writes_nothing_else`;
  `PwaEndpointsTest#test_the_offline_document_renders_English_and_Japanese_copy_with_the_matching_language`;
  `PwaEndpointsTest#test_the_offline_document_carries_no_session,_actor,_or_CSRF_state`.
- `test/controllers/well_known_jwks_controller_test.rb` (4):
  `WellKnownJwksControllerTest#test_core_app_well-known_JWKS_returns_JSON`;
  `WellKnownJwksControllerTest#test_base_org_well-known_JWKS_returns_JSON`;
  `WellKnownJwksControllerTest#test_base_app_well-known_JWKS_returns_JSON`;
  `WellKnownJwksControllerTest#test_core_org_well-known_JWKS_returns_JSON`.
- `test/integration/acceptance_wu02_base_rp_state_test.rb` (1):
  `AcceptanceWu02BaseRpStateTest#test_A02-12:_Base_Welcome_and_Selector_work_from_RP_credentials_without_an_Auth_Rails_session`.
- `test/integration/acceptance_wu02_ceremony_purpose_host_test.rb` (1):
  `AcceptanceWu02CeremonyPurposeHostTest#test_A02-9:_Base_refuses_Sign-in_path_bindings_before_changing_their_binding,_ceremony,_or_transaction`.
- `test/integration/acceptance_wu02_jwks_separation_test.rb` (1):
  `AcceptanceWu02JwksSeparationTest#test_A02-6:_Visa_and_Base_JWKS_have_disjoint_kids_and_public_key_material_in_every_realm`.
- `test/integration/acme_roots_test.rb` (8):
  `SurfaceHealthEndpointTest#test_acme_com_health_responds_successfully`;
  `SurfaceHealthEndpointTest#test_acme_app_health_responds_successfully`;
  `SurfaceHealthEndpointTest#test_acme_org_health_responds_successfully`;
  `SurfaceRootsControllerTest#test_acme_org_www_root_with_a_region_renders_the_control-plane_home`;
  `SurfaceRootsControllerTest#test_acme_app_www_root_with_a_region_renders_the_control-plane_home`;
  `SurfaceRootsControllerTest#test_acme_app_root_without_a_region_renders_the_control-plane_home_after_region_canonicalization`;
  `SurfaceRootsControllerTest#test_acme_com_root_without_a_region_renders_the_control-plane_home_after_region_canonicalization`;
  `SurfaceRootsControllerTest#test_acme_org_root_without_a_region_renders_the_control-plane_home_after_region_canonicalization`.
- `test/integration/apple_auth_test.rb` (1):
  `AppleAuthTest#test_callback_initializes_preference_timezone_options_when_missing`.
- `test/integration/auth_region_contract_test.rb` (1):
  `AuthRegionContractTest#test_every_generated_link_on_an_entry_page_carries_the_requested_region`.
- `test/integration/base_org_iam_owner_api_test.rb` (1):
  `BaseOrgIamOwnerApiTest#test_IAM_grant_and_revoke_commit_through_the_owner_boundary_and_preserve_the_API_response_shape`.
- `test/integration/contact_registration_otp_bootstrap_receipt_recovery_test.rb` (2):
  `ContactRegistrationOtpBootstrapReceiptRecoveryTest#test_app_email_bootstrap_retries_bootstrap_receipt_Ticket_failure_without_granting_freshness`;
  `ContactRegistrationOtpBootstrapReceiptRecoveryTest#test_app_email_bootstrap_retries_contact_receipt_Ticket_failure_without_granting_freshness`.
- `test/integration/contact_registration_otp_http_resend_test.rb` (4):
  `ContactRegistrationOtpHttpResendTest#test_APP_email_HTTP_resend_verified_source_fault_retains_original_flow_proof_and_failure_budgets`;
  `ContactRegistrationOtpHttpResendTest#test_APP_email_HTTP_resend_cooldown_after_retains_original_flow_proof_and_failure_budgets`;
  `ContactRegistrationOtpHttpResendTest#test_APP_email_HTTP_resend_cooldown_before_retains_original_flow_proof_and_failure_budgets`;
  `ContactRegistrationOtpHttpResendTest#test_APP_email_HTTP_resend_cooldown_at_retains_original_flow_proof_and_failure_budgets`.
- `test/integration/contact_settings_otp_atomic_commit_test.rb` (2):
  `ContactSettingsOtpAtomicCommitTest#test_app_settings_email_binding_failure_preserves_verification_and_identical_HTTP_retry`;
  `ContactSettingsOtpAtomicCommitTest#test_app_settings_telephone_binding_failure_preserves_verification_and_identical_HTTP_retry`.
- `test/integration/content_surface_boundary_test.rb` (1):
  `ContentSurfaceBoundaryTest#test_docs_help_and_news_entries_remain_public_read-only_json_surfaces`.
- `test/integration/cookie_settings_authority_test.rb` (1):
  `CookieSettingsAuthorityTest#test_warp_surfaces_omit_preference_controls_when_their_family_has_no_endpoints`.
- `test/integration/core_access_refusal_refresh_retention_test.rb` (1):
  `CoreAccessRefusalRefreshRetentionTest#test_all_surfaces_refuse_bad_access_without_deleting_or_rotating_an_independently_valid_refresh_credential`.
- `test/integration/core_browser_origin_boundary_test.rb` (5):
  `CoreBrowserOriginBoundaryTest#test_same_Origin_contradicting_cross-site_metadata_is_refused_on_every_surface`;
  `CoreBrowserOriginBoundaryTest#test_app_and_org_reject_missing_Origin_with_sibling-site_metadata_despite_valid_csrf`;
  `CoreBrowserOriginBoundaryTest#test_Origin_rejection_precedes_changes_to_real_app_and_org_refresh_credentials`;
  `CoreBrowserOriginBoundaryTest#test_every_surface_rejects_foreign_malformed_null_and_mismatched_Origins_before_refresh`;
  `CoreBrowserOriginBoundaryTest#test_exact_same_Origin_keeps_the_existing_explicit_POST_refresh_refusal_contract`.
- `test/integration/core_rp_cookie_surface_contract_test.rb` (1):
  `CoreRpCookieSurfaceContractTest#test_app_and_org_accept_only_their_exact_RP_access_credential`.
- `test/integration/cross_surface_token_test.rb` (2):
  `CrossSurfaceTokenTest#test_app_preference_token_is_ignored_by_the_org_cookie_endpoint`;
  `CrossSurfaceTokenTest#test_org_preference_token_is_ignored_by_the_app_cookie_endpoint`.
- `test/integration/cycle_close_authenticated_roots_test.rb` (3):
  `CycleCloseAuthenticatedRootsTest#test_an_unrecognized_ri_does_not_redirect_off-host`;
  `CycleCloseAuthenticatedRootsTest#test_twelve_in-scope_roots_answer_on_their_host_and_do_not_open-redirect`;
  `CycleCloseAuthenticatedRootsTest#test_anonymous_Base_Dashboard_enters_passive_sign_and_the_retired_lobby_remains_absent`.
- `test/integration/edit_org_jump_rt_sign_in_test.rb` (3):
  `EditOrgJumpRtSignInTest#test_canonical_Edit_sends_a_protected_page_to_its_passive_sign_entry`;
  `EditOrgJumpRtSignInTest#test_cross-site_Edit_sign_POST_raises_rather_than_falling_back_to_a_Jump_issuer`;
  `EditOrgJumpRtSignInTest#test_canonical_Edit_sign_POST_starts_its_same-site_OIDC_admission_without_a_Jump_RT`.
- `test/integration/email_signup_base_root_completion_test.rb` (1):
  `EmailSignupBaseRootCompletionTest#test_app_email_signup_binds_its_original_OIDC_browser_and_Visa_commits_exactly_one_root`.
- `test/integration/email_signup_http_delivery_commit_test.rb` (12):
  `EmailSignupHttpDeliveryCommitTest#test_APP_initial_Email_signup_remains_reachable_when_notification_enqueue_is_refused`;
  `EmailSignupHttpDeliveryCommitTest#test_APP_Email_receipt_preserves_a_committed_registration_after_the_OP_completion_update_fails`;
  `EmailSignupHttpDeliveryCommitTest#test_APP_Sign_In_Email_address_Cancel_ends_the_parent_through_Visa_and_renders_Base_interruption`;
  `EmailSignupHttpDeliveryCommitTest#test_APP_telephone_OTP_cancellation_reaches_the_shared_interruption_page`;
  `EmailSignupHttpDeliveryCommitTest#test_APP_Sign_Up_method_selection_Cancel_ends_the_parent_through_Visa_and_renders_Base_interruption`;
  `EmailSignupHttpDeliveryCommitTest#test_APP_Sign_In_Passkey_Cancel_ends_the_parent_through_Visa_and_renders_Base_interruption`;
  `EmailSignupHttpDeliveryCommitTest#test_APP_Sign_In_method_selection_Cancel_ends_the_parent_through_Visa_and_renders_Base_interruption`;
  `EmailSignupHttpDeliveryCommitTest#test_APP_signup_after_abandoning_sign-in_cannot_use_a_registered_email_code_or_reach_birthdate_commit`;
  `EmailSignupHttpDeliveryCommitTest#test_APP_initial_Email_signup_commits_its_Flow_and_OTP_before_enqueue`;
  `EmailSignupHttpDeliveryCommitTest#test_APP_Sign_Up_Telephone_number_Cancel_ends_the_parent_through_Visa_and_renders_Base_interruption`;
  `EmailSignupHttpDeliveryCommitTest#test_APP_Sign_In_Secret_Cancel_ends_the_parent_through_Visa_and_renders_Base_interruption`;
  `EmailSignupHttpDeliveryCommitTest#test_APP_Sign_Up_Email_address_Cancel_ends_the_parent_through_Visa_and_renders_Base_interruption`.
- `test/integration/flipper_ui_surface_test.rb` (1):
  `FlipperUiSurfaceTest#test_application_surfaces_keep_the_strict-dynamic_script_policy`.
- `test/integration/health_revision_contract_test.rb` (27):
  `HealthRevisionContractTest#test_a_degraded_but_acceptable_readiness_is_warn_on_the_wire,_and_still_HTTP_200`;
  `HealthRevisionContractTest#test_a_readiness_outage_is_503_on_readiness_and_the_machine_aggregate,_but_liveness_still_passes`;
  `HealthRevisionContractTest#test_GET_/health_is_the_seven-line_text_aggregate_in_the_fixed_order`;
  `HealthRevisionContractTest#test_GET_/api/v0/health.json_returns_406_for_a_non-JSON_Accept,_not_a_text_or_HTML_fallback`;
  `HealthRevisionContractTest#test_GET_/api/v0/health.json_is_the_pass/warn/fail_schema_as_application/json,_never_text_or_HTML`;
  `HealthRevisionContractTest#test_wildcard_and_browser_Accept_headers_are_served_as_JSON`;
  `HealthRevisionContractTest#test_GET_/revision_stays_text/plain_under_a_JSON_or_HTML_Accept`;
  `HealthRevisionContractTest#test_the_JSON_revision_carries_X-Robots-Tag,_and_its_406_carries_only_the_cache_directive`;
  `HealthRevisionContractTest#test_HEAD_/revision_matches_GET_on_status,_content_type,_and_cache,_with_an_empty_body`;
  `HealthRevisionContractTest#test_an_Accept_naming_only_an_unregistered_media_type_is_refused_with_406`;
  `HealthRevisionContractTest#test_a_q-value_of_zero_is_not_honoured:_the_endpoint_still_answers_JSON`;
  `HealthRevisionContractTest#test_GET_/revision_issues_no_database_query`;
  `HealthRevisionContractTest#test_GET_/api/v0/health.json_body_leaks_no_internal_detail`;
  `HealthRevisionContractTest#test_each_text_probe_returns_exactly_"ok\n"_as_text/plain,_never_JSON_or_HTML,_no_redirect`;
  `HealthRevisionContractTest#test_GET_/api/v0/revision.json_returns_revision_and_timestamp_as_JSON,_never_text_or_HTML`;
  `HealthRevisionContractTest#test_text_probes_stay_text/plain_under_a_JSON,_HTML,_or_wildcard_Accept`;
  `HealthRevisionContractTest#test_HEAD_on_the_machine_JSON_endpoints_mirrors_GET_and_carries_an_empty_body`;
  `HealthRevisionContractTest#test_GET_/revision_is_the_revision_status_block_as_text/plain_with_no-store_and_X-Robots-Tag`;
  `HealthRevisionContractTest#test_the_text_health_aggregate_reports_the_failing_probe_and_answers_503`;
  `HealthRevisionContractTest#test_GET_/revision_with_a_nil_application_revision_has_an_empty_revision_value_and_is_a_normal_200`;
  `HealthRevisionContractTest#test_a_simultaneous_warn_and_fail_aggregates_to_fail_and_503`;
  `HealthRevisionContractTest#test_a_machine_JSON_endpoint_with_no_Accept_header_is_served,_not_refused`;
  `HealthRevisionContractTest#test_GET_/api/v0/revision.json_preserves_a_nil_application_revision_alongside_its_timestamp`;
  `HealthRevisionContractTest#test_a_snapshot_missing_a_probe_raises_instead_of_rendering_a_blank_line`;
  `HealthRevisionContractTest#test_revision_representations_include_their_UTC_render_timestamp`;
  `HealthRevisionContractTest#test_GET_/api/v0/revision.json_issues_no_database_query`;
  `HealthRevisionContractTest#test_GET_/api/v0/revision.json_returns_406_for_a_non-JSON_Accept,_not_a_text_or_HTML_fallback`.
- `test/integration/html_title_contract_test.rb` (12):
  `HtmlTitleContractTest#test_root_pages_render_the_brand_alone`;
  `HtmlTitleContractTest#test_every_routed_GET_HTML_page_carries_a_non-empty_title_on_ORG_(www-jp.umaxica.org)`;
  `HtmlTitleContractTest#test_every_routed_GET_HTML_page_carries_a_non-empty_title_on_ORG_(www.umaxica.org)`;
  `HtmlTitleContractTest#test_every_routed_GET_HTML_page_carries_a_non-empty_title_on_ORG_(jp.umaxica.org)`;
  `HtmlTitleContractTest#test_every_routed_GET_HTML_page_carries_a_non-empty_title_on_DEV_(core.dev.localhost)`;
  `HtmlTitleContractTest#test_every_routed_GET_HTML_page_carries_a_non-empty_title_on_APP_(jp.umaxica.app)`;
  `HtmlTitleContractTest#test_the_health_snapshot_is_a_non-HTML_probe_and_is_excluded_from_title_contracts`;
  `HtmlTitleContractTest#test_every_routed_GET_HTML_page_carries_a_non-empty_title_on_APP_(palm-jp.umaxica.app)`;
  `HtmlTitleContractTest#test_every_routed_GET_HTML_page_carries_a_non-empty_title_on_APP_(www.umaxica.app)`;
  `HtmlTitleContractTest#test_every_routed_GET_HTML_page_carries_a_non-empty_title_on_COM_(www.umaxica.com)`;
  `HtmlTitleContractTest#test_every_routed_GET_HTML_page_carries_a_non-empty_title_on_APP_(www-jp.umaxica.app)`;
  `HtmlTitleContractTest#test_every_routed_GET_HTML_page_carries_a_non-empty_title_on_COM_(www-jp.umaxica.com)`.
- `test/integration/jump_directed_handoffs_test.rb` (3):
  `JumpDirectedHandoffsTest#test_Auth_sign_out_uses_same_TLD_public_Base_through_Jump_and_direct_ceremony_entry_is_refused`;
  `JumpDirectedHandoffsTest#test_Edit_sign_POST_keeps_its_existing_same-site_authorization_admission_pending_separate_RP_review`;
  `JumpDirectedHandoffsTest#test_Core_and_Warp_sign_entry_POST_uses_Jump_with_public_Base_even_on_the_same_site`.
- `test/integration/jump_rt_issuer_jwks_authority_test.rb` (1):
  `JumpRtIssuerJwksAuthorityTest#test_canonical_Jump_issuers_sign_RT_and_the_routing_surfaces_publish_the_exact_signing_key`.
- `test/integration/jump_rt_return_verification_test.rb` (17):
  `JumpRtReturnVerificationTest#test_acme_app_rejects_invalid_jump_return_rt_before_normal_auth_flow`;
  `JumpRtReturnVerificationTest#test_a_Jump-signed_return_with_a_duplicated_reserved_parameter_is_rejected`;
  `JumpRtReturnVerificationTest#test_Auth_org_and_Palm_verify_Base_returns_and_clean_the_return_token`;
  `JumpRtReturnVerificationTest#test_Auth_org_and_Palm_reject_invalid_returns_before_their_normal_flow`;
  `JumpRtReturnVerificationTest#test_rails_issued_rt_can_round_trip_through_a_stubbed_jump_gateway_and_return_verifier`;
  `JumpRtReturnVerificationTest#test_a_verified_Jump_return_does_not_follow_a_downstream_redirect_parameter_off_the_receiving_host`;
  `JumpRtReturnVerificationTest#test_sign_app_consumes_valid_jump_return_rt_and_strips_it_from_url`;
  `JumpRtReturnVerificationTest#test_a_request_whose_only_return_token_key_is_nested_is_rejected_before_the_normal_flow`;
  `JumpRtReturnVerificationTest#test_acme_app_consumes_valid_jump_return_rt_and_strips_it_from_url`;
  `JumpRtReturnVerificationTest#test_a_valid_Jump_return_token_does_not_exempt_an_unsafe_Base_request_from_CSRF`;
  `JumpRtReturnVerificationTest#test_a_signed_return_with_a_source_path_is_rejected_without_redirecting`;
  `JumpRtReturnVerificationTest#test_a_Jump_return_whose_source_edge_is_not_approved_is_rejected_even_with_a_valid_signature`;
  `JumpRtReturnVerificationTest#test_a_verified_Jump_return_redirects_to_the_signed_target_with_order_and_repeated_pairs_intact`;
  `JumpRtReturnVerificationTest#test_rejected_jump_return_logs_do_not_include_the_rt_token`;
  `JumpRtReturnVerificationTest#test_a_Jump-signed_return_with_a_second_rt_is_rejected`;
  `JumpRtReturnVerificationTest#test_sign_app_rejects_invalid_jump_return_rt_before_normal_auth_flow`;
  `JumpRtReturnVerificationTest#test_a_Jump-signed_return_with_reordered_pairs_is_rejected`.
- `test/integration/oidc_closures_receiver_gating_test.rb` (1):
  `OidcClosuresReceiverGatingTest#test_a_request_without_a_browser_User-Agent_or_cookies_reaches_the_token_check`.
- `test/integration/oidc_current_device_logout_test.rb` (5):
  `OidcCurrentDeviceLogoutTest#test_org_confirmation_stops_both_rotated_roots_and_their_grants_on_the_current_device`;
  `OidcCurrentDeviceLogoutTest#test_APP_RP_logout_leaves_the_signed-in_ORG_browser_usable_on_its_next_request`;
  `OidcCurrentDeviceLogoutTest#test_org_leaving_Visa_confirmation_keeps_the_OP_session_and_both_grants_active`;
  `OidcCurrentDeviceLogoutTest#test_app_leaving_Visa_confirmation_keeps_the_OP_session_and_both_grants_active`;
  `OidcCurrentDeviceLogoutTest#test_app_confirmation_stops_both_rotated_roots_and_their_grants_on_the_current_device`.
- `test/integration/oidc_rp_default_landing_test.rb` (1):
  `OidcRpDefaultLandingTest#test_public_OIDC_callbacks_honor_a_target_or_the_explicit_RP_landing`.
- `test/integration/oidc_rp_logout_edit_return_test.rb` (1):
  `OidcRpLogoutEditReturnTest#test_Edit_RP_returns_through_Visa_ORG_and_Base_ORG_self-RP_returns_to_Base_staff`.
- `test/integration/oidc_rp_logout_sibling_scope_test.rb` (1):
  `OidcRpLogoutSiblingScopeTest#test_positive_control:_the_sibling_credentials_are_accepted_before_the_sign-out`.
- `test/integration/org_oidc_auth_handoff_root_completion_test.rb` (5):
  `OrgOidcAuthHandoffRootCompletionTest#test_org_real_OIDC_Entra_and_Passkey_preference_failure_preserves_Base_root_authority`;
  `OrgOidcAuthHandoffRootCompletionTest#test_org_real_OIDC_Entra_and_Passkey_expired_mfa_preserves_Base_root_authority`;
  `OrgOidcAuthHandoffRootCompletionTest#test_org_real_OIDC_Entra_and_Passkey_complete_preserves_Base_root_authority`;
  `OrgOidcAuthHandoffRootCompletionTest#test_org_real_OIDC_Entra_and_Passkey_missing_mfa_preserves_Base_root_authority`;
  `OrgOidcAuthHandoffRootCompletionTest#test_org_real_OIDC_Entra_and_Passkey_missing_primary_preserves_Base_root_authority`.
- `test/integration/org_social_login_blocked_test.rb` (1):
  `OrgSocialLoginBlockedTest#test_app_Google_provider_request_on_staff_host_redirects_to_callback`.
- `test/integration/plain_response_localization_test.rb` (4):
  `PlainResponseLocalizationTest#test_google_plain_signup_refusals_use_ja_without_advancing_the_flow`;
  `PlainResponseLocalizationTest#test_apple_plain_signup_refusals_use_en_without_advancing_the_flow`;
  `PlainResponseLocalizationTest#test_google_plain_signup_refusals_use_en_without_advancing_the_flow`;
  `PlainResponseLocalizationTest#test_apple_plain_signup_refusals_use_ja_without_advancing_the_flow`.
- `test/integration/preference_bootstrap_idempotency_test.rb` (1):
  `PreferenceBootstrapIdempotencyTest#test_cookie-less_preference_GET_does_not_bootstrap_or_persist_a_preference`.
- `test/integration/preference_browser_api_contract_test.rb` (16):
  `PreferenceBrowserApiContractTest#test_an_invalid_foreign-host_Preference_JWT_is_never_used_to_seed_a_Base_write`;
  `PreferenceBrowserApiContractTest#test_Auth,_Core,_and_Warp_read_default_preferences_without_issuing_or_persisting_state`;
  `PreferenceBrowserApiContractTest#test_Auth,_Core,_and_Warp_keep_Preference_display_read-only`;
  `PreferenceBrowserApiContractTest#test_an_Accept_that_excludes_JSON_is_a_406_problem`;
  `PreferenceBrowserApiContractTest#test_an_anonymous_com_token_is_readable_on_another_com_host_and_is_not_a_credential_in_another_realm`;
  `PreferenceBrowserApiContractTest#test_a_cross-site_PATCH_without_a_valid_CSRF_token_is_forbidden_and_changes_nothing`;
  `PreferenceBrowserApiContractTest#test_PATCH_theme_stores_each_accepted_spelling_and_answers_the_stored_code`;
  `PreferenceBrowserApiContractTest#test_a_body_that_is_not_declared_as_application/json_is_a_415_problem`;
  `PreferenceBrowserApiContractTest#test_a_PATCH_with_no_preference_credential_at_all_is_served`;
  `PreferenceBrowserApiContractTest#test_PATCH_theme_refuses_every_other_value_with_a_422_pointing_at_/theme`;
  `PreferenceBrowserApiContractTest#test_a_request_without_Accept_is_served`;
  `PreferenceBrowserApiContractTest#test_Base_realm_theme_writes_issue_400-day_preference_and_shared-cookie_expiries`;
  `PreferenceBrowserApiContractTest#test_media-type_refusals_come_before_CSRF_and_credential_checks`;
  `PreferenceBrowserApiContractTest#test_PATCH_cookie_refuses_a_missing_or_unreadable_decision_with_a_422_naming_each_field`;
  `PreferenceBrowserApiContractTest#test_GET_answers_JSON,_no-store,_and_writes_no_preference_row`;
  `PreferenceBrowserApiContractTest#test_PATCH_cookie_returns_the_recorded_decision_for_every_Base_realm`.
- `test/integration/preference_credential_recovery_matrix_test.rb` (2):
  `PreferenceCredentialRecoveryMatrixTest#test_a_valid_APP_anonymous_JWT_is_refused_by_ORG_without_writing_an_ORG_row`;
  `PreferenceCredentialRecoveryMatrixTest#test_malformed_anonymous_JWTs_on_APP_and_ORG_GETs_create_no_preference_rows`.
- `test/integration/preference_get_edit_current_behavior_test.rb` (2):
  `PreferenceGetEditCurrentBehaviorTest#test_GET_edit_does_not_create_a_missing_child_preference_row`;
  `PreferenceGetEditCurrentBehaviorTest#test_GET_edit_still_renders_a_default_value_when_the_child_row_is_missing`.
- `test/integration/rp_sign_interruption_test.rb` (1):
  `RpSignInterruptionTest#test_the_interruption_page_answers_200_no-store_with_the_fixed_text_on_every_RP`.
- `test/integration/sign_app_oidc_browser_flow_test.rb` (1):
  `SignAppOidcBrowserFlowTest#test_auth_settings_do_not_initiate_an_OIDC_RP_flow`.
- `test/integration/sign_in_path_browser_allowlist_test.rb` (1):
  `SignInPathBrowserAllowlistTest#test_the_Back-Channel_Logout_receiver_is_not_gated_on_the_browser_version`.
- `test/integration/social_auth_link_test.rb` (4):
  `SocialAuthLinkTest#test_link_intent_requires_authentication`;
  `SocialAuthLinkTest#test_Google_link_callback_stages_evidence_before_a_receiver-local_POST_creates_one_identity`;
  `SocialAuthLinkTest#test_guest_cannot_start_Google_linking`;
  `SocialAuthLinkTest#test_guest_cannot_start_Apple_linking`.
- `test/integration/social_auth_unlink_test.rb` (1):
  `SocialAuthUnlinkTest#test_unlink_requires_authentication`.
- `test/integration/surface_chrome_preference_controls_test.rb` (4):
  `SurfaceChromePreferenceControlsTest#test_warp_com_renders_a_read-only_link_to_Base_cookie_settings`;
  `SurfaceChromePreferenceControlsTest#test_core_receives_no_interactive_Preference_controls`;
  `SurfaceChromePreferenceControlsTest#test_palm_app_renders_no_theme_or_cookie_controls_even_though_it_is_an_app_surface`;
  `SurfaceChromePreferenceControlsTest#test_page_chrome_exposes_browser_write_endpoints_only_to_Base`.
- `test/integration/telephone_signup_http_delivery_test.rb` (5):
  `TelephoneSignupHttpDeliveryTest#test_app_actual_Telephone_signup_queues_encrypted_code_and_refuses_reissued_stale_transport`;
  `TelephoneSignupHttpDeliveryTest#test_app_actual_Telephone_signup_queues_encrypted_code_and_refuses_cancelled_stale_transport`;
  `TelephoneSignupHttpDeliveryTest#test_APP_signup_after_abandoning_sign-in_cannot_use_a_registered_telephone_code_or_reach_birthdate_commit`;
  `TelephoneSignupHttpDeliveryTest#test_app_actual_Telephone_signup_queues_encrypted_code_and_refuses_current_stale_transport`;
  `TelephoneSignupHttpDeliveryTest#test_app_actual_Telephone_signup_queues_encrypted_code_and_refuses_expired_stale_transport`.
- `test/integration/telephone_signup_source_proof_retry_test.rb` (4):
  `TelephoneSignupSourceProofRetryTest#test_app_telephone_signup_ceremony_proof_survives_Ticket_verify_contact_failure_and_HTTP_retry`;
  `TelephoneSignupSourceProofRetryTest#test_app_telephone_signup_ceremony_proof_survives_Ticket_clear_requirement_failure_and_HTTP_retry`;
  `TelephoneSignupSourceProofRetryTest#test_app_telephone_signup_ceremony_proof_survives_Ticket_enter_guardrail_failure_and_HTTP_retry`;
  `TelephoneSignupSourceProofRetryTest#test_app_telephone_signup_ceremony_proof_survives_Ticket_enter_checkpoint_failure_and_HTTP_retry`.
- `test/integration/vite_entrypoint_contract_test.rb` (2):
  `ViteEntrypointContractTest#test_every_Inertia_layout_loads_the_entrypoint_belonging_to_its_own_surface`;
  `ViteEntrypointContractTest#test_every_surface_stylesheet_is_linked_by_a_template`.
- `test/integration/warp_sso_start_contract_test.rb` (2):
  `WarpSsoStartContractTest#test_cross-site_sign-in_starts_issue_a_surface-bound_Jump_RT_on_app_and_org`;
  `WarpSsoStartContractTest#test_missing_Jump_RT_signing_keys_raise_a_configuration_failure_on_app_and_org`.
- `test/integration/wua6_publishing_context_parity_test.rb` (1):
  `Wua6PublishingContextParityTest#test_ORG_Publishing_create_accepts_the_same_active_operator_under_Normal_and_Standby`.
- `test/integration/wua6_standby_support_revocation_screen_test.rb` (1):
  `Wua6StandbySupportRevocationScreenTest#test_ORG_read-only_owner_screens_deny_Standby_and_allow_Normal_with_fresh_matching_Step-Up`.
- `test/integration/xper_retired_hosts_test.rb` (1):
  `XperRetiredHostsTest#test_a_retained_Base_host_still_owns_the_same_endpoint_paths`.
- `test/jobs/client_secret_audit_delivery_job_test.rb` (1):
  `ClientSecretAuditDeliveryJobTest#test_a_conflicting_Secret_audit_does_not_starve_later_pages`.
- `test/jobs/enforcement_reconciliation_job_test.rb` (2):
  `EnforcementReconciliationJobTest#test_completes_the_end_audit_for_an_approved_appeal_whose_case_already_ended`;
  `EnforcementReconciliationJobTest#test_ends_an_active_case_whose_approved_appeal_did_not_finish_ending_it`.
- `test/operations/identity_step_up_totp_device_concurrency_test.rb` (1):
  `IdentityStepUpTotpDeviceConcurrencyTest#test_Ticket_evidence_commits_before_a_waiting_device_revocation`.
- `test/services/branch_coverage_batch3_services_test.rb` (1):
  `BranchCoverageBatch3ServicesTest#test_AcmeSelectableContext_persist_selection!_requires_session`.
- `test/services/identity/email_ceremony_contract_test.rb` (1):
  `IdentityEmailCeremonyContractTest#test_signature_verification_rejects_wrong_key_and_tampering`.
- `test/services/identity/passkey_ceremony_contract_test.rb` (1):
  `IdentityPasskeyCeremonyContractTest#test_signature_verification_rejects_wrong_key_and_tampering`.
- `test/services/identity/secret_credential_ceremony_contract_test.rb` (1):
  `IdentitySecretCredentialCeremonyContractTest#test_signature_verification_rejects_wrong_key_and_tampering`.
- `test/services/identity/social_ceremony_contract_test.rb` (1):
  `IdentitySocialCeremonyContractTest#test_signature_verification_rejects_wrong_key_and_tampering`.
- `test/services/identity/step_up_ceremony_contract_test.rb` (1):
  `IdentityStepUpCeremonyContractTest#test_signature_verification_rejects_wrong_key_and_payload_tampering`.
- `test/services/identity/telephone_ceremony_contract_test.rb` (1):
  `IdentityTelephoneCeremonyContractTest#test_signature_verification_rejects_wrong_key_tampered_payload_wrong_kid_and_wrong_issuer_audience`.
- `test/services/identity/totp_ceremony_contract_test.rb` (1):
  `IdentityTotpCeremonyContractTest#test_signature_verification_rejects_wrong_key_and_tampering`.
- `test/support/browser_rp_logout_flow_helper.rb` (1):
  `OidcRpLogoutSiblingScopeTest#test_a_root_stop_sends_a_signed_back-channel_logout_to_each_sibling_grant`.
- `test/tooling/architecture_baseline_test.rb` (1):
  `ArchitectureBaselineTest#test_baseline_does_not_list_resolved_files`.
- `test/tooling/object_placement_test.rb` (1):
  `ObjectPlacementTest#test_every_file_names_its_own_role`.
- `test/unit/core/surface_test.rb` (1):
  `Main::SurfaceTest#test_falls_back_to_com_when_host_has_no_surface_subdomain`.
- `test/unit/security/public_entrypoint_inventory_test.rb` (1):
  `Security::PublicEntrypointInventoryTest#test_PUBLIC_PWA_OFFLINE_covers_exactly_the_two_Rails_PWA_endpoints`.
- `test/unit/security/redirect_target_usage_test.rb` (1):
  `RedirectTargetUsageTest#test_allow_other_host_true_is_limited_to_reviewed_Jump_and_protocol_handoff_boundaries`.
- `test/unit/security/ri_routing_contract_test.rb` (4):
  `RiRoutingContractTest#test_set_region_is_skipped_only_in_the_reviewed_allowlist`;
  `RiRoutingContractTest#test_every_participating_target_wires_up_the_ri_mechanism_on_its_ApplicationController`;
  `RiRoutingContractTest#test_every_routing_target_is_classified_as_participating_in_or_exempt_from_the_ri_contract`;
  `RiRoutingContractTest#test_every_routed_controller_rendering_HTML_resolves_set_region_in_its_effective_callback_chain`.

The original pre-split suite was recorded only as an aggregate (17,164 runs, 146,002 assertions, 302
failures, 192 errors); its named failures were not saved. Therefore individual
pre-existing-vs-change attribution remains unavailable. The 255 current failures remain open and
were not represented as passing.

## Output handling

Complete test output and a machine-generated failure-ID file remain under `/tmp` only; neither is
copied into this evidence. No credential, key, cookie, token, or sensitive request value is
recorded.
