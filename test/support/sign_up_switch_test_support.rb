# frozen_string_literal: true

# Starts an Auth App sign-up ceremony through its RP-issued OIDC authorization transaction.
module AuthSignUpAdmissionTestSupport
  AUTH_HOST_ENV = "PUBLIC_AUTH_SERVICE_URL"

  def admit_browser_to_sign_up!(browser, surface: "app")
    raise ArgumentError, "Auth sign-up admission is available only on the App surface" unless surface.to_s == "app"

    auth_host = ENV.fetch(AUTH_HOST_ENV)
    browser.host!(auth_host)
    browser.https!

    issuance = OidcTestEntry.issue!(
      surface:, intent: "sign_up", base_browser_nonce: SecureRandom.urlsafe_base64(32), base_token: nil,
    )
    path = auth_app_sign_up_path(ri: "jp")
    admit_auth_ceremony_entry!(path, reference: issuance.reference, browser:)

    target = URI.parse(browser.response.location)
    raise RuntimeError, "Auth sign-up admission redirected outside Auth" if target.host && target.host != auth_host

    browser.get(target.request_uri, headers: { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" })
    raise RuntimeError, "Auth sign-up admission did not render its entry page" unless browser.response.successful?

    browser
  end
end

ActiveSupport.on_load(:action_dispatch_integration_test) { include AuthSignUpAdmissionTestSupport }
