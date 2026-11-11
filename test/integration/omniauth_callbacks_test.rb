# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../support/oidc_auth_admission_test_helper"
# require "helpers/global_test_support"

class OmniauthCallbacksTest < ActionDispatch::IntegrationTest
  include OidcAuthAdmissionTestHelper

  fixtures :client_statuses,
           :client_totp_credential_statuses

  setup do
    OmniAuth.config.test_mode = true
    TurnstileVerifierStub.challenge_enabled = true
    TurnstileVerifierStub.challenge_response = { "success" => true }
    # The ceremony runs on the Auth host the application is configured with: a request
    # made to any other host gets a session cookie the application does not read back,
    # so the sign-up ticket is lost and the flow restarts instead of advancing.
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! @host
    @expected_redirect = %r{\Ahttps?://#{Regexp.escape(@host)}/.*}.freeze
  end

  teardown do
    OmniAuth.config.mock_auth[:google] = nil
    OmniAuth.config.mock_auth[:apple] = nil
    TurnstileVerifierStub.challenge_enabled = false
    TurnstileVerifierStub.challenge_response = nil
    ClientTokenBindingMethod.ensure_defaults!
    ClientTokenDbscStatus.ensure_defaults!
    ClientTokenKind.ensure_defaults!
    ClientTokenStatus.ensure_defaults!
  end

  test "unknown Google identity enters sign up checkpoint instead of signing in" do
    # IMPORTANT: Social login uses provider+uid ONLY, NOT email
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      {
        provider: "google",
        uid: "123456789",
        info: {
          image: "http://example.com/image.jpg",
        },
        credentials: {
          token: "token",
          refresh_token: "refresh_token",
          expires_at: 1.week.from_now.to_i,
        },
      },
    )

    state =
      begin
        flow0_provider = "google"
        flow0_intent = "login"
        flow0_user = nil
        flow0_entry = "sign_up"
        flow0_ri = "jp"
        flow0_rt = nil
        flow0_referer = nil
        unless flow0_intent.to_s == "link"
          bootstrap_auth_sign_in_admission!
        end
        flow0_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
        host!(flow0_host)
        flow0_normalized_provider = SocialIdentifiable.normalize_provider(flow0_provider)
        flow0_continue_path =
          if flow0_intent.to_s == "link"
            ((if flow0_normalized_provider == "google"
                auth_app_settings_google_path(ri: flow0_ri)
              else
                auth_app_settings_apple_path(ri: flow0_ri)
              end))
          elsif flow0_entry.to_s == "sign_up"
            ((flow0_normalized_provider == "google") ? auth_app_social_google_registration_path(
              ri: flow0_ri,
              rt: flow0_rt,
            ) : auth_app_social_apple_registration_path(
              ri: flow0_ri,
              rt: flow0_rt,
            ))
          else
            ((flow0_normalized_provider == "google") ? auth_app_social_google_session_path(
              ri: flow0_ri,
              rt: flow0_rt,
            ) : auth_app_social_apple_session_path(
              ri: flow0_ri,
              rt: flow0_rt,
            ))
          end
        flow0_headers = social_callback_headers(flow0_host)
        flow0_headers["Referer"] = flow0_referer if flow0_referer.present?
        if flow0_user
          flow0_user_headers =
            as_user_headers(flow0_user, host: flow0_host)
          flow0_token = ClientToken.find_by(public_id: flow0_user_headers["X-TEST-SESSION-PUBLIC-ID"])
          mark_token_step_up_satisfied_for_test(
            flow0_token,
            scope: SocialAuth::SOCIAL_LINK_SCOPE,
          ) if flow0_intent.to_s == "link" && flow0_token
          flow0_headers = flow0_headers.merge(flow0_user_headers)
        end
        if flow0_entry.to_s == "sign_up" && flow0_intent.to_s != "link"
          admit_browser_to_sign_up!(integration_session)
          host!(flow0_host)
        end
        post(flow0_continue_path, headers: flow0_headers)
        social_auth_state_from_response
      end

    assert_no_difference("Client.count") do
      assert_no_difference("ClientGoogleIdentity.count") do
        get auth_app_social_google_callback_url(ri: "jp"),
            params: { state: state },
            headers: social_callback_headers(@host)
      end
    end

    assert_redirected_to auth_app_sign_up_guard_google_url(ri: "jp")
    follow_redirect!

    assert_redirected_to auth_app_sign_up_check_google_confirmation_url(
      ri: "jp", fb: SignFlowBindingCodec.encode(
        flow: session_sign_up_flow(session, surface: :app),
        surface: :app,
      ),
    )
    follow_redirect!

    # The social sign-up checkpoint asks for an explicit confirmation before an identity is

    # created; the page object names that component and carries the label it asks agreement to.

    assert_equal "auth/app/sign/up/check/social/confirmations/show", inertia_component

    assert_predicate inertia_props.fetch("confirm_label"), :present?
  end

  test "google callback without region parameter is processed without regional redirect" do
    # The regional behaviour of the sign-in callback is only observable when the
    # callback actually completes a login: an unregistered verified subject is now
    # refused with the verified-subject guidance page instead (rule 7).
    existing_uid = "google_no_region_#{SecureRandom.hex(4)}"
    existing_user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::NOTHING,
      birthdate: "2000-01-01",
    )
    ClientGoogleIdentity.create!(
      user: existing_user,
      uid: existing_uid,
      provider: "google",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      {
        provider: "google",
        uid: existing_uid,
        info: {},
        credentials: {
          token: "token",
          refresh_token: "refresh_token",
          expires_at: 1.week.from_now.to_i,
        },
      },
    )

    state =
      begin
        flow1_provider = "google"
        begin
          flow2_provider = flow1_provider
          flow2_intent = "login"
          flow2_user = nil
          flow2_entry = nil
          flow2_ri = "jp"
          flow2_rt = nil
          flow2_referer = nil
          unless flow2_intent.to_s == "link"
            bootstrap_auth_sign_in_admission!
          end
          flow2_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
          host!(flow2_host)
          flow2_normalized_provider = SocialIdentifiable.normalize_provider(flow2_provider)
          flow2_continue_path =
            if flow2_intent.to_s == "link"
              ((if flow2_normalized_provider == "google"
                  auth_app_settings_google_path(ri: flow2_ri)
                else
                  auth_app_settings_apple_path(ri: flow2_ri)
                end))
            elsif flow2_entry.to_s == "sign_up"
              ((flow2_normalized_provider == "google") ? auth_app_social_google_registration_path(
                ri: flow2_ri,
                rt: flow2_rt,
              ) : auth_app_social_apple_registration_path(
                ri: flow2_ri,
                rt: flow2_rt,
              ))
            else
              ((flow2_normalized_provider == "google") ? auth_app_social_google_session_path(
                ri: flow2_ri,
                rt: flow2_rt,
              ) : auth_app_social_apple_session_path(
                ri: flow2_ri,
                rt: flow2_rt,
              ))
            end
          flow2_headers = social_callback_headers(flow2_host)
          flow2_headers["Referer"] = flow2_referer if flow2_referer.present?
          if flow2_user
            flow2_user_headers =
              as_user_headers(flow2_user, host: flow2_host)
            flow2_token = ClientToken.find_by(public_id: flow2_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              flow2_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if flow2_intent.to_s == "link" && flow2_token
            flow2_headers = flow2_headers.merge(flow2_user_headers)
          end
          if flow2_entry.to_s == "sign_up" && flow2_intent.to_s != "link"
            admit_browser_to_sign_up!(integration_session)
            host!(flow2_host)
          end
          post(flow2_continue_path, headers: flow2_headers)
          social_auth_state_from_response
        end
      end

    get auth_app_social_google_callback_url,
        params: { state: state },
        headers: social_callback_headers(@host)

    assert_response :redirect
    assert_not_includes response.location, "code="
  end

  test "unknown Apple identity enters sign up checkpoint instead of signing in" do
    # IMPORTANT: Social login uses provider+uid ONLY, NOT email
    state =
      begin
        flow3_provider = "apple"
        flow3_intent = "login"
        flow3_user = nil
        flow3_entry = "sign_up"
        flow3_ri = "jp"
        flow3_rt = nil
        flow3_referer = nil
        unless flow3_intent.to_s == "link"
          bootstrap_auth_sign_in_admission!
        end
        flow3_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
        host!(flow3_host)
        flow3_normalized_provider = SocialIdentifiable.normalize_provider(flow3_provider)
        flow3_continue_path =
          if flow3_intent.to_s == "link"
            ((if flow3_normalized_provider == "google"
                auth_app_settings_google_path(ri: flow3_ri)
              else
                auth_app_settings_apple_path(ri: flow3_ri)
              end))
          elsif flow3_entry.to_s == "sign_up"
            ((flow3_normalized_provider == "google") ? auth_app_social_google_registration_path(
              ri: flow3_ri,
              rt: flow3_rt,
            ) : auth_app_social_apple_registration_path(
              ri: flow3_ri,
              rt: flow3_rt,
            ))
          else
            ((flow3_normalized_provider == "google") ? auth_app_social_google_session_path(
              ri: flow3_ri,
              rt: flow3_rt,
            ) : auth_app_social_apple_session_path(
              ri: flow3_ri,
              rt: flow3_rt,
            ))
          end
        flow3_headers = social_callback_headers(flow3_host)
        flow3_headers["Referer"] = flow3_referer if flow3_referer.present?
        if flow3_user
          flow3_user_headers =
            as_user_headers(flow3_user, host: flow3_host)
          flow3_token = ClientToken.find_by(public_id: flow3_user_headers["X-TEST-SESSION-PUBLIC-ID"])
          mark_token_step_up_satisfied_for_test(
            flow3_token,
            scope: SocialAuth::SOCIAL_LINK_SCOPE,
          ) if flow3_intent.to_s == "link" && flow3_token
          flow3_headers = flow3_headers.merge(flow3_user_headers)
        end
        if flow3_entry.to_s == "sign_up" && flow3_intent.to_s != "link"
          admit_browser_to_sign_up!(integration_session)
          host!(flow3_host)
        end
        post(flow3_continue_path, headers: flow3_headers)
        social_auth_state_from_response
      end

    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      {
        provider: "apple",
        uid: "apple_uid_123",
        info: {},
        credentials: {
          token: "apple_token",
          refresh_token: "apple_refresh_token",
          expires_at: 1.week.from_now.to_i,
        },
        extra: { id_info: { nonce: session[:social_auth_nonce] } },
      },
    )

    assert_no_difference("Client.count") do
      assert_no_difference("ClientAppleIdentity.count") do
        get auth_app_social_apple_callback_url(provider: "apple", ri: "jp"),
            params: { state: state },
            headers: social_callback_headers(@host)
      end
    end

    assert_redirected_to auth_app_sign_up_guard_apple_url(ri: "jp")
    follow_redirect!

    assert_redirected_to auth_app_sign_up_check_apple_confirmation_url(
      ri: "jp", fb: SignFlowBindingCodec.encode(
        flow: session_sign_up_flow(session, surface: :app),
        surface: :app,
      ),
    )
    follow_redirect!

    # The social sign-up checkpoint asks for an explicit confirmation before an identity is

    # created; the page object names that component and carries the label it asks agreement to.

    assert_equal "auth/app/sign/up/check/social/confirmations/show", inertia_component

    assert_predicate inertia_props.fetch("confirm_label"), :present?
  end

  test "unknown Apple GET callback enters sign up checkpoint instead of signing in" do
    state =
      begin
        flow4_provider = "apple"
        flow4_intent = "login"
        flow4_user = nil
        flow4_entry = "sign_up"
        flow4_ri = "jp"
        flow4_rt = nil
        flow4_referer = nil
        unless flow4_intent.to_s == "link"
          bootstrap_auth_sign_in_admission!
        end
        flow4_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
        host!(flow4_host)
        flow4_normalized_provider = SocialIdentifiable.normalize_provider(flow4_provider)
        flow4_continue_path =
          if flow4_intent.to_s == "link"
            ((if flow4_normalized_provider == "google"
                auth_app_settings_google_path(ri: flow4_ri)
              else
                auth_app_settings_apple_path(ri: flow4_ri)
              end))
          elsif flow4_entry.to_s == "sign_up"
            ((flow4_normalized_provider == "google") ? auth_app_social_google_registration_path(
              ri: flow4_ri,
              rt: flow4_rt,
            ) : auth_app_social_apple_registration_path(
              ri: flow4_ri,
              rt: flow4_rt,
            ))
          else
            ((flow4_normalized_provider == "google") ? auth_app_social_google_session_path(
              ri: flow4_ri,
              rt: flow4_rt,
            ) : auth_app_social_apple_session_path(
              ri: flow4_ri,
              rt: flow4_rt,
            ))
          end
        flow4_headers = social_callback_headers(flow4_host)
        flow4_headers["Referer"] = flow4_referer if flow4_referer.present?
        if flow4_user
          flow4_user_headers =
            as_user_headers(flow4_user, host: flow4_host)
          flow4_token = ClientToken.find_by(public_id: flow4_user_headers["X-TEST-SESSION-PUBLIC-ID"])
          mark_token_step_up_satisfied_for_test(
            flow4_token,
            scope: SocialAuth::SOCIAL_LINK_SCOPE,
          ) if flow4_intent.to_s == "link" && flow4_token
          flow4_headers = flow4_headers.merge(flow4_user_headers)
        end
        if flow4_entry.to_s == "sign_up" && flow4_intent.to_s != "link"
          admit_browser_to_sign_up!(integration_session)
          host!(flow4_host)
        end
        post(flow4_continue_path, headers: flow4_headers)
        social_auth_state_from_response
      end

    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      {
        provider: "apple",
        uid: "apple_get_callback_uid",
        info: {},
        credentials: {
          token: "apple_token",
          refresh_token: "apple_refresh_token",
          expires_at: 1.week.from_now.to_i,
        },
        extra: { id_info: { nonce: session[:social_auth_nonce] } },
      },
    )

    assert_no_difference("Client.count") do
      assert_no_difference("ClientAppleIdentity.count") do
        get auth_app_social_apple_callback_url(provider: "apple", ri: "jp"),
            params: { state: state },
            headers: social_callback_headers(@host)
      end
    end

    assert_redirected_to auth_app_sign_up_guard_apple_url(ri: "jp")
    follow_redirect!

    assert_redirected_to auth_app_sign_up_check_apple_confirmation_url(
      ri: "jp", fb: SignFlowBindingCodec.encode(
        flow: session_sign_up_flow(session, surface: :app),
        surface: :app,
      ),
    )
    follow_redirect!

    # The social sign-up checkpoint asks for an explicit confirmation before an identity is

    # created; the page object names that component and carries the label it asks agreement to.

    assert_equal "auth/app/sign/up/check/social/confirmations/show", inertia_component

    assert_predicate inertia_props.fetch("confirm_label"), :present?
  end

  test "apple social login with MFA enabled enters the ordinary MFA challenge" do
    user = Client.create!(birthdate: "2000-02-03", security_mode_id: SecurityModeConfigurable::ADVANCED)
    ClientTotpCredential.create!(
      user: user,
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      title: "totp",
    )
    ClientAppleIdentity.create!(
      user: user,
      uid: "apple_mfa_skip_uid",
      provider: "apple",
      token: "existing_token",
      expires_at: 1.week.from_now.to_i,
      user_apple_identity_status: client_apple_identity_statuses(:active),
    )

    state =
      begin
        flow5_provider = "apple"
        begin
          flow6_provider = flow5_provider
          flow6_intent = "login"
          flow6_user = nil
          flow6_entry = nil
          flow6_ri = "jp"
          flow6_rt = nil
          flow6_referer = nil
          unless flow6_intent.to_s == "link"
            bootstrap_auth_sign_in_admission!
          end
          flow6_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
          host!(flow6_host)
          flow6_normalized_provider = SocialIdentifiable.normalize_provider(flow6_provider)
          flow6_continue_path =
            if flow6_intent.to_s == "link"
              ((if flow6_normalized_provider == "google"
                  auth_app_settings_google_path(ri: flow6_ri)
                else
                  auth_app_settings_apple_path(ri: flow6_ri)
                end))
            elsif flow6_entry.to_s == "sign_up"
              ((flow6_normalized_provider == "google") ? auth_app_social_google_registration_path(
                ri: flow6_ri,
                rt: flow6_rt,
              ) : auth_app_social_apple_registration_path(
                ri: flow6_ri,
                rt: flow6_rt,
              ))
            else
              ((flow6_normalized_provider == "google") ? auth_app_social_google_session_path(
                ri: flow6_ri,
                rt: flow6_rt,
              ) : auth_app_social_apple_session_path(
                ri: flow6_ri,
                rt: flow6_rt,
              ))
            end
          flow6_headers = social_callback_headers(flow6_host)
          flow6_headers["Referer"] = flow6_referer if flow6_referer.present?
          if flow6_user
            flow6_user_headers =
              as_user_headers(flow6_user, host: flow6_host)
            flow6_token = ClientToken.find_by(public_id: flow6_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              flow6_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if flow6_intent.to_s == "link" && flow6_token
            flow6_headers = flow6_headers.merge(flow6_user_headers)
          end
          if flow6_entry.to_s == "sign_up" && flow6_intent.to_s != "link"
            admit_browser_to_sign_up!(integration_session)
            host!(flow6_host)
          end
          post(flow6_continue_path, headers: flow6_headers)
          social_auth_state_from_response
        end
      end

    OmniAuth.config.mock_auth[:apple] = OmniAuth::AuthHash.new(
      {
        provider: "apple",
        uid: "apple_mfa_skip_uid",
        info: {},
        credentials: {
          token: "apple_token",
          refresh_token: "apple_refresh_token",
          expires_at: 1.week.from_now.to_i,
        },
        extra: { id_info: { nonce: session[:social_auth_nonce] } },
      },
    )

    get auth_app_social_apple_callback_url(provider: "apple", ri: "jp"),
        params: { state: state },
        headers: social_callback_headers(@host)

    # The sign callback only hands evidence to Base. Base applies the ordinary
    # sign-in graph, where social is not a local MFA bypass.
    assert_emits_acme_completion_only!
    assert_response :redirect
    assert_match %r{/sign/in/challenge}, response.location
    assert_predicate session[:pending_mfa], :present?
  end

  test "should sign in with existing Google user" do
    user = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, birthdate: "2000-02-03")
    identity = ClientGoogleIdentity.create!(
      user: user,
      uid: "existing_uid",
      provider: "google",
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    bootstrap_social_auth_admission!(auth: integration_session, auth_host: @host, intent: "sign_in")
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "google",
      uid: "existing_uid",
      info: { image: "http://example.com/image.jpg" },
      credentials: {
        token: "provider-fixture",
        refresh_token: "refresh-fixture",
        expires_at: 1.week.from_now.to_i,
      },
    )

    post auth_app_social_google_session_path(ri: "jp"), headers: @callback_headers

    assert_response :temporary_redirect
    state = social_auth_state_from_response

    assert_predicate state, :present?

    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: }, headers: @callback_headers

    assert_emits_acme_completion_only!

    get auth_app_sign_oidc_handoff_path(ri: "jp"), headers: {
      "Host" => @host,
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Site" => "same-origin",
    }
    result_target = URI.parse(jump_rt_url_from_location_for_test(response.location))
    visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")

    assert_equal [visa_host, "/oidc/result"], [result_target.host, result_target.path]
    complete_social_oidc_visa_result!(
      target: result_target,
      visa_browser: @visa_browser,
      visa_host:,
    )

    assert_response :redirect
    assert_equal user.id, identity.reload.user_id
  end

  test "existing Google identity without birthdate stays on login side" do
    user = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL)
    ClientGoogleIdentity.create!(
      user: user,
      uid: "existing_missing_birthdate_uid",
      provider: "google",
      token: "existing_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      {
        provider: "google",
        uid: "existing_missing_birthdate_uid",
        info: {},
        credentials: {
          token: "new_token",
          refresh_token: "new_refresh_token",
          expires_at: 1.week.from_now.to_i,
        },
      },
    )

    state =
      begin
        flow10_provider = "google"
        begin
          flow11_provider = flow10_provider
          flow11_intent = "login"
          flow11_user = nil
          flow11_entry = nil
          flow11_ri = "jp"
          flow11_rt = nil
          flow11_referer = nil
          unless flow11_intent.to_s == "link"
            bootstrap_auth_sign_in_admission!
          end
          flow11_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
          host!(flow11_host)
          flow11_normalized_provider = SocialIdentifiable.normalize_provider(flow11_provider)
          flow11_continue_path =
            if flow11_intent.to_s == "link"
              ((if flow11_normalized_provider == "google"
                  auth_app_settings_google_path(ri: flow11_ri)
                else
                  auth_app_settings_apple_path(ri: flow11_ri)
                end))
            elsif flow11_entry.to_s == "sign_up"
              ((flow11_normalized_provider == "google") ? auth_app_social_google_registration_path(
                ri: flow11_ri,
                rt: flow11_rt,
              ) : auth_app_social_apple_registration_path(
                ri: flow11_ri,
                rt: flow11_rt,
              ))
            else
              ((flow11_normalized_provider == "google") ? auth_app_social_google_session_path(
                ri: flow11_ri,
                rt: flow11_rt,
              ) : auth_app_social_apple_session_path(
                ri: flow11_ri,
                rt: flow11_rt,
              ))
            end
          flow11_headers = social_callback_headers(flow11_host)
          flow11_headers["Referer"] = flow11_referer if flow11_referer.present?
          if flow11_user
            flow11_user_headers =
              as_user_headers(flow11_user, host: flow11_host)
            flow11_token = ClientToken.find_by(public_id: flow11_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              flow11_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if flow11_intent.to_s == "link" && flow11_token
            flow11_headers = flow11_headers.merge(flow11_user_headers)
          end
          if flow11_entry.to_s == "sign_up" && flow11_intent.to_s != "link"
            admit_browser_to_sign_up!(integration_session)
            host!(flow11_host)
          end
          post(flow11_continue_path, headers: flow11_headers)
          social_auth_state_from_response
        end
      end

    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: social_callback_headers(@host)

    assert_equal URI.parse(auth_app_sign_in_check_url(ri: "jp")).path, URI.parse(response.location).path
    assert_not ClientToken.exists?(user_id: user.id), "ClientToken must not be created before birthdate checkpoint"
  end

  test "social login with MFA enabled enters the ordinary MFA challenge" do
    user = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, birthdate: "2000-02-03")
    user.update!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    ClientTotpCredential.create!(
      user: user,
      private_key: ROTP::Base32.random_base32,
      user_totp_credential_status_id: ClientTotpCredentialStatus::ACTIVE,
      title: "totp",
    )
    ClientGoogleIdentity.create!(
      user: user,
      uid: "totp_required_uid",
      provider: "google",
      token: "existing_token",
      refresh_token: "existing_refresh",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      {
        provider: "google",
        uid: "totp_required_uid",
        info: { image: "http://example.com/image.jpg" },
        credentials: {
          token: "new_token",
          refresh_token: "new_refresh",
          expires_at: 1.week.from_now.to_i,
        },
      },
    )

    state =
      begin
        flow12_provider = "google"
        begin
          flow13_provider = flow12_provider
          flow13_intent = "login"
          flow13_user = nil
          flow13_entry = nil
          flow13_ri = "jp"
          flow13_rt = nil
          flow13_referer = nil
          unless flow13_intent.to_s == "link"
            bootstrap_auth_sign_in_admission!
          end
          flow13_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
          host!(flow13_host)
          flow13_normalized_provider = SocialIdentifiable.normalize_provider(flow13_provider)
          flow13_continue_path =
            if flow13_intent.to_s == "link"
              ((if flow13_normalized_provider == "google"
                  auth_app_settings_google_path(ri: flow13_ri)
                else
                  auth_app_settings_apple_path(ri: flow13_ri)
                end))
            elsif flow13_entry.to_s == "sign_up"
              ((flow13_normalized_provider == "google") ? auth_app_social_google_registration_path(
                ri: flow13_ri,
                rt: flow13_rt,
              ) : auth_app_social_apple_registration_path(
                ri: flow13_ri,
                rt: flow13_rt,
              ))
            else
              ((flow13_normalized_provider == "google") ? auth_app_social_google_session_path(
                ri: flow13_ri,
                rt: flow13_rt,
              ) : auth_app_social_apple_session_path(
                ri: flow13_ri,
                rt: flow13_rt,
              ))
            end
          flow13_headers = social_callback_headers(flow13_host)
          flow13_headers["Referer"] = flow13_referer if flow13_referer.present?
          if flow13_user
            flow13_user_headers =
              as_user_headers(flow13_user, host: flow13_host)
            flow13_token = ClientToken.find_by(public_id: flow13_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              flow13_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if flow13_intent.to_s == "link" && flow13_token
            flow13_headers = flow13_headers.merge(flow13_user_headers)
          end
          if flow13_entry.to_s == "sign_up" && flow13_intent.to_s != "link"
            admit_browser_to_sign_up!(integration_session)
            host!(flow13_host)
          end
          post(flow13_continue_path, headers: flow13_headers)
          social_auth_state_from_response
        end
      end

    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: social_callback_headers(@host)

    # The sign callback only hands evidence to Base. Base applies the ordinary
    # sign-in graph, where social is not a local MFA bypass.
    assert_emits_acme_completion_only!
    assert_response :redirect
    assert_match %r{/sign/in/challenge}, response.location
    assert_predicate session[:pending_mfa], :present?
  end

  test "google login with missing user_token_kind does not crash callback" do
    ClientToken.delete_all
    ClientTokenKind.delete_all

    # The missing reference rows are only exercised by a callback that actually
    # completes a login: an unregistered verified subject is now refused with the
    # verified-subject guidance page instead (rule 7).
    existing_user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::NOTHING,
      birthdate: "2000-01-01",
    )
    ClientGoogleIdentity.create!(
      user: existing_user,
      uid: "missing_kind_uid",
      provider: "google",
      token: "old_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      {
        provider: "google",
        uid: "missing_kind_uid",
        info: {
          image: "http://example.com/image.jpg",
        },
        credentials: {
          token: "token",
          refresh_token: "refresh_token",
          expires_at: 1.week.from_now.to_i,
        },
      },
    )

    state =
      begin
        flow14_provider = "google"
        begin
          flow15_provider = flow14_provider
          flow15_intent = "login"
          flow15_user = nil
          flow15_entry = nil
          flow15_ri = "jp"
          flow15_rt = nil
          flow15_referer = nil
          unless flow15_intent.to_s == "link"
            bootstrap_auth_sign_in_admission!
          end
          flow15_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
          host!(flow15_host)
          flow15_normalized_provider = SocialIdentifiable.normalize_provider(flow15_provider)
          flow15_continue_path =
            if flow15_intent.to_s == "link"
              ((if flow15_normalized_provider == "google"
                  auth_app_settings_google_path(ri: flow15_ri)
                else
                  auth_app_settings_apple_path(ri: flow15_ri)
                end))
            elsif flow15_entry.to_s == "sign_up"
              ((flow15_normalized_provider == "google") ? auth_app_social_google_registration_path(
                ri: flow15_ri,
                rt: flow15_rt,
              ) : auth_app_social_apple_registration_path(
                ri: flow15_ri,
                rt: flow15_rt,
              ))
            else
              ((flow15_normalized_provider == "google") ? auth_app_social_google_session_path(
                ri: flow15_ri,
                rt: flow15_rt,
              ) : auth_app_social_apple_session_path(
                ri: flow15_ri,
                rt: flow15_rt,
              ))
            end
          flow15_headers = social_callback_headers(flow15_host)
          flow15_headers["Referer"] = flow15_referer if flow15_referer.present?
          if flow15_user
            flow15_user_headers =
              as_user_headers(flow15_user, host: flow15_host)
            flow15_token = ClientToken.find_by(public_id: flow15_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              flow15_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if flow15_intent.to_s == "link" && flow15_token
            flow15_headers = flow15_headers.merge(flow15_user_headers)
          end
          if flow15_entry.to_s == "sign_up" && flow15_intent.to_s != "link"
            admit_browser_to_sign_up!(integration_session)
            host!(flow15_host)
          end
          post(flow15_continue_path, headers: flow15_headers)
          social_auth_state_from_response
        end
      end

    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: social_callback_headers(@host)

    assert_response :redirect
  end

  test "google login with session limit exceeded redirects to session management" do
    # Create an existing user with Google social identity
    user = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, birthdate: "2000-02-03")
    ClientGoogleIdentity.create!(
      user: user,
      uid: "session_limit_uid",
      provider: "google",
      token: "existing_token",
      expires_at: 1.week.from_now.to_i,
      user_google_identity_status: client_google_identity_statuses(:active),
    )

    # Create 2 active sessions to hit the limit
    ClientToken.where(user_id: user.id).delete_all
    2.times do
      create_rotated_active_user_session(user, rotations: 3)
    end

    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      {
        provider: "google",
        uid: "session_limit_uid",
        info: { image: "http://example.com/image.jpg" },
        credentials: {
          token: "new_token",
          refresh_token: "new_refresh_token",
          expires_at: 1.week.from_now.to_i,
        },
      },
    )

    sessions_before = ClientToken.where(user_id: user.id).count

    state =
      begin
        flow16_provider = "google"
        begin
          flow17_provider = flow16_provider
          flow17_intent = "login"
          flow17_user = nil
          flow17_entry = nil
          flow17_ri = "jp"
          flow17_rt = nil
          flow17_referer = nil
          unless flow17_intent.to_s == "link"
            bootstrap_auth_sign_in_admission!
          end
          flow17_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
          host!(flow17_host)
          flow17_normalized_provider = SocialIdentifiable.normalize_provider(flow17_provider)
          flow17_continue_path =
            if flow17_intent.to_s == "link"
              ((if flow17_normalized_provider == "google"
                  auth_app_settings_google_path(ri: flow17_ri)
                else
                  auth_app_settings_apple_path(ri: flow17_ri)
                end))
            elsif flow17_entry.to_s == "sign_up"
              ((flow17_normalized_provider == "google") ? auth_app_social_google_registration_path(
                ri: flow17_ri,
                rt: flow17_rt,
              ) : auth_app_social_apple_registration_path(
                ri: flow17_ri,
                rt: flow17_rt,
              ))
            else
              ((flow17_normalized_provider == "google") ? auth_app_social_google_session_path(
                ri: flow17_ri,
                rt: flow17_rt,
              ) : auth_app_social_apple_session_path(
                ri: flow17_ri,
                rt: flow17_rt,
              ))
            end
          flow17_headers = social_callback_headers(flow17_host)
          flow17_headers["Referer"] = flow17_referer if flow17_referer.present?
          if flow17_user
            flow17_user_headers =
              as_user_headers(flow17_user, host: flow17_host)
            flow17_token = ClientToken.find_by(public_id: flow17_user_headers["X-TEST-SESSION-PUBLIC-ID"])
            mark_token_step_up_satisfied_for_test(
              flow17_token,
              scope: SocialAuth::SOCIAL_LINK_SCOPE,
            ) if flow17_intent.to_s == "link" && flow17_token
            flow17_headers = flow17_headers.merge(flow17_user_headers)
          end
          if flow17_entry.to_s == "sign_up" && flow17_intent.to_s != "link"
            admit_browser_to_sign_up!(integration_session)
            host!(flow17_host)
          end
          post(flow17_continue_path, headers: flow17_headers)
          social_auth_state_from_response
        end
      end

    get auth_app_social_google_callback_url(ri: "jp"),
        params: { state: state },
        headers: social_callback_headers(@host)

    # Session-limit enforcement belongs to base completion. The sign callback
    # emits the completion form only and must not create or restrict a sign-side
    # session token of its own.
    assert_emits_acme_completion_only!

    assert_equal sessions_before, ClientToken.where(user_id: user.id).count,
                 "sign must not establish a session token for an established social login"
    restricted = ClientToken.where(user_id: user.id, user_token_status_id: ClientTokenStatus::RESTRICTED)

    assert_equal 0, restricted.count
  end

  private

  # Auth records ceremony evidence; Root issuance remains on the original Base parent.
  def assert_emits_acme_completion_only!
    assert_response :see_other
    target = URI.parse(response.location.to_s)

    assert_equal ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), target.host
    assert_includes ["/sign/in/check", "/sign/in/challenge"], target.path
    assert_nil cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
  end

  def create_rotated_active_user_session(user, rotations:)
    token = ClientToken.create!(authentication_epoch: 0, user: user, user_token_status_id: ClientTokenStatus::ACTIVE)
    refresh = token.rotate_refresh_token!

    rotations.times do
      refresh = AuthRefreshTokenIssuer.call(refresh_token: refresh)[:refresh_token]
    end
  end
end

# DAMP local helper copy for former shared test support.
class OmniauthCallbacksTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
  TEST_VERIFICATION_COOKIE_PREFIX = "test_verified:"

  private

  def configured_host(surface_name)
    Rails.configuration.x.boot_config.fetch(:hosts).public_send(surface_name).host
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service = normalized.include?("acme") ? "ACME" : (normalized.include?("core") ? "CORE" : "AUTH")
    surface =
      if service == "AUTH"
        case resource_type
        when "operator" then "ORG"
        else "APP"
        end
      elsif normalized.include?(".org") || normalized.include?("org.")
        "ORG"
      else
        "APP"
      end
    "surface:#{service}_#{surface}"
  end

  def ensure_user_reference_records!
    ClientStatus.find_or_create_by!(id: ClientStatus::NOTHING)
    ClientVisibility.find_or_create_by!(id: ClientVisibility::USER)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::NOTHING)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::ACTIVE)
    ClientMfaStatus.find_or_create_by!(id: ClientMfaStatus::UNCONFIGURED)
    ClientEmailStatus.find_or_create_by!(id: ClientEmailStatus::VERIFIED)
    ClientTelephoneStatus.find_or_create_by!(id: ClientTelephoneStatus::VERIFIED)
    ClientPasskeyStatus.find_or_create_by!(id: ClientPasskeyStatus::ACTIVE)
  end

  def ensure_user_token_reference_records!
    ClientTokenKind.find_or_create_by!(id: ClientTokenKind::BROWSER_WEB)
    ClientTokenStatus.find_or_create_by!(id: ClientTokenStatus::ACTIVE)
    ClientTokenBindingMethod.find_or_create_by!(id: ClientTokenBindingMethod::LEGACY)
    ClientTokenDbscStatus.find_or_create_by!(id: ClientTokenDbscStatus::NOTHING)
  end

  def ensure_staff_token_reference_records!
    OperatorTokenKind.find_or_create_by!(id: OperatorTokenKind::BROWSER_WEB)
    OperatorTokenStatus.find_or_create_by!(id: OperatorTokenStatus::ACTIVE)
    OperatorTokenBindingMethod.find_or_create_by!(id: OperatorTokenBindingMethod::LEGACY)
    OperatorTokenDbscStatus.find_or_create_by!(id: OperatorTokenDbscStatus::NOTHING)
  end

  def create_verified_user_with_email(email_address: "user-#{SecureRandom.hex(4)}@example.com")
    ensure_user_reference_records!
    user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::NOTHING,
      visibility_id: ClientVisibility::USER,
    )
    insert_verified_user_email!(user_id: user.id, address: email_address)
    user.reload
  end

  def insert_verified_user_email!(user_id:, address:)
    ClientEmail.create!(
      user_id: user_id,
      address: address,
      address_digest: IdentifierBlindIndex.bidx_for_email(address, realm: :app),
      user_email_status_id: ClientEmailStatus::VERIFIED,
      otp_attempts_count: 0,
      public_id: SecureRandom.alphanumeric(21),
    )
  end

  def satisfy_user_verification(token, scope: nil)
    _verification, raw_token = ClientVerification.issue_for_token!(token: token)
    cookies[ClientVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def satisfy_staff_verification(token, scope: nil)
    _verification, raw_token = OperatorVerification.issue_for_token!(token: token)
    cookies[OperatorVerification.cookie_name] = raw_token
    mark_token_step_up_satisfied_for_test(token, scope: scope)
    true
  end

  def step_up_test_audience_for_token(token)
    case token.class.name
    when "OperatorToken" then "step_up:org"
    else "step_up:app"
    end
  end

  def signed_step_up_pt_for(path, surface:, session_nonce:)
    safe_path = path.to_s
    return nil if safe_path.blank? || !safe_path.start_with?("/") || safe_path.match?(/[\x00-\x1F\x7F]/)

    verifier = ActiveSupport::MessageVerifier.new(
      Rails.application.key_generator.generate_key("path_target_token", 32),
      digest: "SHA256",
      serializer: JSON,
      url_safe: true,
    )
    verifier.generate(
      { "flow" => "step_up.bootstrap",
        "surface" => surface.to_s,
        "session_nonce" => session_nonce.to_s,
        "pt" => safe_path, },
      purpose: :path_target,
      expires_in: 15.minutes,
    )
  end

  def signed_step_up_grant_for(actor:, token:, scope:, return_to:, surface:, methods: %i(email_otp totp passkey),
                               aal: "aal2")
    IdentityStepUpCeremonyGrantIssuer.issue!(
      surface: surface.to_s,
      actor_ref: actor.public_id,
      session_ref: token.public_id,
      required_scope: scope.to_s,
      required_aal: aal,
      allowed_methods: methods,
      return_to: return_to,
      expires_at: 15.minutes.from_now,
    ).grant
  end

  def with_forgery_protection
    ActionController::Base.allow_forgery_protection = true
    yield
  ensure
    # Restore the environment default, not the value observed on entry: if the flag was
    # already leaked as true, restoring the observation would pin the leak for the rest
    # of the process and every later test expecting protection off would fail.
    ActionController::Base.allow_forgery_protection =
      Rails.configuration.action_controller.allow_forgery_protection
  end

  def csrf_token_value
    "test-csrf-token"
  end

  def csrf_headers(token)
    { "X-CSRF-Token" => token }
  end

  def fetch_csrf_token(path)
    get(path)
    response.body[/name="authenticity_token" value="([^"]+)"/, 1] || response.body
  end

  def social_callback_headers(host)
    scheme = host.to_s.include?("localhost") ? "http" : "https"
    origin = "#{scheme}://#{host}"
    cookies["csrf_token"] = csrf_token_value if respond_to?(:cookies)
    {
      "Host" => host,
      "Origin" => origin,
      "Referer" => "#{origin}/",
      "Sec-Fetch-Site" => "same-origin",
      "X-STRICT-SOCIAL-STATE" => "1",
      "X-CSRF-Token" => csrf_token_value,
    }
  end

  def social_auth_state_from_response
    session[:social_auth_state].presence || begin
      uri = URI.parse(response.location.to_s)
      Rack::Utils.parse_nested_query(uri.query.to_s)["state"].presence
    rescue URI::InvalidURIError
      nil
    end
  end

  def assert_oidc_authorize_redirect(location, host:, client_id: "base-rails-rp")
    uri = URI.parse(location)
    query = Rack::Utils.parse_nested_query(uri.query.to_s)

    assert_equal host, uri.host
    assert_equal "/oauth/authorize", uri.path
    assert_equal client_id, query["client_id"]
    assert_predicate query["state"], :present?
  end
end

# DAMP local social completion helpers for former shared test support.
class OmniauthCallbacksTest
  private
end

# DAMP local route helper aliases for former shared test support.
class OmniauthCallbacksTest

  private



end

# DAMP local helper copy on the test class.
class OmniauthCallbacksTest
  TEST_BROWSER_USER_AGENT =
    "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
    "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" unless const_defined?(
      :TEST_BROWSER_USER_AGENT, false,
    )

  private

  def set_access_cookie(token)
    cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = token
  end

  def set_refresh_cookie(token)
    cookies[AuthenticationBase::REFRESH_COOKIE_KEY] = token
  end

  def jump_rt_url_from_location(location)
    uri = URI.parse(location.to_s)
    return location unless uri.host == "jump.umaxica.net"

    token = Rack::Utils.parse_nested_query(uri.query.to_s)["rt"]
    return location if token.blank?

    payload, = JWT.decode(token, nil, false)
    payload["url"].presence || location
  rescue JWT::DecodeError, URI::InvalidURIError
    location
  end

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = { "Client-Agent" => self.class::TEST_BROWSER_USER_AGENT }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = csrf_token_value
    cookies["csrf_token"] = csrf_token if respond_to?(:cookies, true)
    host_headers.merge("X-CSRF-Token" => csrf_token)
  end

  def mark_token_step_up_satisfied_for_test(token, scope: nil, at: Time.current)
    return unless token.respond_to?(:update_columns)

    token.update_columns(
      { last_step_up_at: at,
        last_step_up_scope: scope.presence || token.try(:last_step_up_scope).presence || "verification",
        updated_at: Time.current, }.compact,
    )
  end

  def load_jump_rt_env!
    @jump_rt_env_originals ||= {}
    jump_rt_key = Base64.strict_encode64(OpenSSL::PKey::EC.generate("secp384r1").to_der)
    %w(AUTH_APP AUTH_ORG ACME_APP ACME_ORG CORE_APP CORE_ORG BASE_APP BASE_ORG).each do |namespace|
      ENV["JWT_#{namespace}_ACTIVE_KID"] = "#{namespace.downcase.tr("_", "-")}-test"
      ENV["JWT_#{namespace}_PRIVATE_KEY"] = jump_rt_key
    end
    ENV["PUBLIC_JUMP_GATEWAY_URL"] = "https://jump.umaxica.net"
    JitSecurityJwtRegistry.reload! if defined?(JitSecurityJwtRegistry)
  end

  def response_set_cookie_lines
    raw = response.headers["Set-Cookie"] || response.headers["set-cookie"]
    lines = raw.is_a?(Array) ? raw : raw.to_s.split("\n")
    lines.flat_map { |line| line.to_s.split("\n") }.compact_blank
  end

  def extract_cookies_from_response
    response_set_cookie_lines.each_with_object({}) do |line, parsed|
      pair = line.to_s.split(";", 2).first
      name, value = pair.to_s.split("=", 2)
      parsed[name] = CGI.unescape(value.to_s) if name.present?
    end
  end

  def state_changing_application_route_targets
    Rails.application.routes.routes.filter_map do |route|
      verbs = route.verb.to_s.delete("^A-Z|").split("|")
      next if verbs.empty? || (verbs - %w(GET HEAD)).empty?

      controller = route.required_defaults[:controller].to_s
      action = route.required_defaults[:action].to_s
      next if controller.blank? || action.blank?

      controller_class_name = "#{controller.camelize}Controller"
      next unless Rails.root.join("app/controllers/#{controller}_controller.rb").exist?

      { verb: verbs.join("|"),
        path: route.path.spec.to_s,
        controller: controller,
        action: action,
        controller_class: Object.const_get(controller_class_name), }
    rescue NameError
      nil
    end
  end

  def setup_google_mock_auth(uid: "google_uid_123", email: "google@example.com")
    OmniAuth.config.mock_auth[:google_app] =
      OmniAuth::AuthHash.new(
        provider: "google_app", uid: uid, info: { email: email, name: "Google Client" },
        credentials: { token: "google_token", expires_at: 1.hour.from_now.to_i },
      )
  end
end
