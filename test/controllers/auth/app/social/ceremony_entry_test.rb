# typed: false
# frozen_string_literal: true

require "test_helper"
require_relative "../../../../support/oidc_auth_admission_test_helper"

# What the POST entry writes before handing the request to the OmniAuth request
# phase. The handoff itself and the absence of a GET entry are covered by
# test/integration/social_ceremony_entry_contract_test.rb.
class Auth::App::Social::CeremonyEntryTest < ActionDispatch::IntegrationTest
  include OidcAuthAdmissionTestHelper

  setup do
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! auth_host
    https!
    issuance = OidcTestEntry.issue!(
      surface: "app", intent: "sign_in", base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    admit_auth_ceremony_entry!(auth_app_sign_in_path(ri: "jp"), reference: issuance.reference)
    follow_redirect!

    assert_response :success
  end

  test "sign-in entry binds provider state to the admitted SID without a signed social grant" do
    assert_no_difference(["ClientToken.count", "ClientSocialCeremonyTransaction.count"]) do
      post auth_app_social_google_session_path(provider: "google", ri: "jp")
    end

    assert_response :temporary_redirect
    assert_nil session[SocialAuth::SOCIAL_CEREMONY_GRANT_SESSION_KEY]
    assert_nil session[SocialAuth::SOCIAL_INTENT_SESSION_KEY]
    assert_nil session[SocialAuth::SOCIAL_STARTED_AT_SESSION_KEY]
    assert_nil session[SocialAuth::SOCIAL_FLOW_ID_SESSION_KEY]
    assert_nil session[SocialAuth::SOCIAL_PROVIDER_SESSION_KEY]
    assert_nil session[SocialAuth::SOCIAL_PT_SESSION_KEY]
    state = session[SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY]

    assert_predicate state, :present?
    assert_equal "google", session[SocialCallbackGuard::SOCIAL_STATE_PROVIDER_SESSION_KEY]
    assert_equal "sign_in", session[SocialAuth::SOCIAL_ENTRY_SESSION_KEY]
    assert ClientAuthCeremonySession.where.not(admitted_at: nil).any?(&:active?)
  end

  %w(google apple).each do |provider|
    test "#{provider} sign-up attempt issues its sign-up flow at the verified callback" do
      previous_test_mode = OmniAuth.config.test_mode
      OmniAuth.config.test_mode = true
      OmniAuth.config.mock_auth[provider.to_sym] = OmniAuth::AuthHash.new(
        provider: provider, uid: "entry-flow-#{provider}-#{SecureRandom.hex(4)}", info: { name: "Fixture" },
        credentials: { token: "fixture", expires_at: 1.hour.from_now.to_i },
      )
      admit_browser_to_sign_up!(integration_session)
      # The entry hands off to the provider without issuing a Flow; the verified
      # callback issues the attempt's one Flow (AppSocialCeremonyEntry).
      assert_no_difference("ClientSignUpFlow.count") do
        post(public_send(:"auth_app_social_#{provider}_registration_path", provider: provider, ri: "jp"))
      end

      assert_response :temporary_redirect
      state = session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)

      assert_difference("ClientSignUpFlow.count", 1) do
        get(
          public_send(:"auth_app_social_#{provider}_callback_path"),
          params: { state: state, ri: "jp" },
          headers: {
            "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}", "Sec-Fetch-Site" => "same-origin",
          },
        )
      end

      assert_response :found
      cycle = ClientSignUpFlow.order(:created_at).last

      assert_equal provider, cycle.entry_method
      assert_equal provider, cycle.social_provider
      assert_equal "checkpoint", cycle.step
      assert_equal cycle.public_id, session[:auth_app_up_sequence_id]
    ensure
      OmniAuth.config.mock_auth[provider.to_sym] = nil
      OmniAuth.config.test_mode = previous_test_mode
    end
  end

  # WU-05c (R2-A, A05-3/A05-4): a sign-up attempt owns one Flow; a callback whose
  # admission already owns a Flow is refused and never creates a replacement.
  test "a sign-up callback whose entry Flow already exists is refused and creates no Flow" do
    previous_test_mode = OmniAuth.config.test_mode
    OmniAuth.config.test_mode = true
    OmniAuth.config.mock_auth[:google] = OmniAuth::AuthHash.new(
      provider: "google", uid: "entry-flow-#{SecureRandom.hex(4)}", info: { name: "Fixture" },
      credentials: { token: "fixture", expires_at: 1.hour.from_now.to_i },
    )
    admit_browser_to_sign_up!(integration_session)
    post(auth_app_social_google_registration_path(ri: "jp"))

    assert_response :temporary_redirect
    state = session.fetch(SocialCallbackGuard::SOCIAL_STATE_SESSION_KEY)

    # The entry issues no Flow; stage the attempt's own Flow as an already-issued
    # one, which is the state a second issuance must never duplicate.
    binding = ClientAuthAdmissionBinding.order(:id).last
    now = Time.current
    ClientSignUpFlow.create!(
      auth_admission_binding: binding,
      principal_id: nil,
      status_id: ClientSignUpFlowStatus::STARTED,
      step: "start",
      nonce_digest: ClientSignUpFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
      issued_at: now,
      expires_at: now + 10.minutes,
      entry_method: "google",
      social_provider: "google",
      return_to: auth_app_sign_up_path(ri: "jp"),
    )

    assert_no_difference(["ClientSignUpFlow.count", "Client.count"]) do
      get(
        auth_app_social_google_callback_path, params: { state: state, ri: "jp" }, headers: {
          "Origin" => "https://#{ENV.fetch("PUBLIC_AUTH_SERVICE_URL")}", "Sec-Fetch-Site" => "same-origin",
        },
      )
    end
    # D-73: the callback must not issue a second Flow for an admission that already
    # owns one, so the uniform error ends nothing.
    assert_response :bad_request
  ensure
    OmniAuth.config.mock_auth[:google] = nil
    OmniAuth.config.test_mode = previous_test_mode
  end

  # The provider comes from a route default, so an unsupported one is not
  # reachable through routing. Only the two supported providers have routes.
  test "no route exists for a provider outside the supported set" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/social/microsoft/session", method: :post)
    end
  end
end
