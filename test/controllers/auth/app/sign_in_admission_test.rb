# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::SignInAdmissionTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! @host
    https!
  end

  test "direct entry without admission is refused and starts no ceremony" do
    get auth_app_sign_in_url(ri: "jp"), headers: { "Host" => @host }

    assert_response :bad_request
    assert_nil response.location
    assert_nil session[:oidc_authorization_login_challenge]
    assert_nil cookies["auth_sid"]
  end

  test "legacy admission query is rejected without consuming a code" do
    issuance = OidcTestEntry.issue!(
      surface: "app",
      intent: "sign_in",
      base_browser_nonce: "nnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnnn",
      base_token: nil,
    )

    get auth_app_sign_in_url(ri: "jp", admission: issuance.code), headers: { "Host" => @host }

    assert_response :bad_request
    assert_includes response.body, I18n.t("errors.messages.invalid_request")
  end

  test "google and apple callback routes remain at their existing paths" do
    assert_recognizes(
      { controller: "auth/app/omniauth/omniauth_callbacks", action: "omniauth", provider: "google" },
      { path: "http://#{@host}/social/google/callback", method: :get },
    )
    assert_recognizes(
      { controller: "auth/app/omniauth/omniauth_callbacks", action: "omniauth", provider: "apple" },
      { path: "http://#{@host}/social/apple/callback", method: :get },
    )
  end
end
