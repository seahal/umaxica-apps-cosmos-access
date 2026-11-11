# typed: false
# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

class AcceptanceWu29SentryToggleTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  SURFACES = [
    ["app", "PUBLIC_AUTH_SERVICE_URL"],
    ["org", "PUBLIC_AUTH_STAFF_URL"],
  ].freeze

  FLOWS = %w(sign_in sign_up).freeze

  setup do
    @previous_flags = SURFACES.flat_map do |surface, _host_env|
      FLOWS.map do |flow|
        feature = FeatureFlags::REGISTRY.fetch(:"#{flow}_available_#{surface}").name
        [feature, Flipper.enabled?(feature)]
      end
    end.to_h
  end

  teardown do
    @previous_flags.each do |feature, enabled|
      enabled ? Flipper.enable(feature) : Flipper.disable(feature)
    end
  end

  test "A29-7: each surface and flow reads availability again on the next request" do
    SURFACES.each do |surface, host_env|
      FLOWS.each do |flow|
        feature = FeatureFlags::REGISTRY.fetch(:"#{flow}_available_#{surface}").name
        path = (flow == "sign_in") ? "/sign/in/sentry" : "/sign/up/sentry"
        host = ENV.fetch(host_env)
        browser = open_session
        browser.host!(host)
        browser.https!

        Flipper.enable(feature)
        browser.get(path, params: { ri: "jp" })

        assert_equal 303, browser.response.status, "#{surface} #{flow} allowed before the flag changes"
        assert_equal "/sign/#{(flow == "sign_in") ? "in" : "up"}", URI.parse(browser.response.location).path

        Flipper.disable(feature)
        browser.get(path, params: { ri: "jp" })

        assert_equal 503, browser.response.status, "#{surface} #{flow} must observe ALLOWED → BLOCKED"
        assert_equal "no-store", browser.response.headers["Cache-Control"]

        Flipper.enable(feature)
        browser.get(path, params: { ri: "jp" })

        assert_equal 303, browser.response.status, "#{surface} #{flow} must observe BLOCKED → ALLOWED"
        assert_equal "/sign/#{(flow == "sign_in") ? "in" : "up"}", URI.parse(browser.response.location).path
      end
    end
  end
  test "A29-8 blocked Auth login entries leave Visa step-up available" do
    %i(sign_in_available_app sign_up_available_app).each { |feature| Flipper.disable(feature) }
    auth_host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    visa_host = Rails.configuration.x.boot_config.fetch(:hosts).visa_service.host
    actor = Client.create!(security_mode_id: SecurityModeConfigurable::NORMAL, status_id: ClientStatus::ACTIVE)
    token = ClientToken.create!(
      authentication_epoch: 0,
      user: actor,
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
      root_login_established_at: ClientToken.database_now,
    )
    token.rotate_refresh_token!
    fake = WebAuthn::FakeClient.new("https://#{auth_host}", encoding: :base64url)
    registration = fake.create(challenge: SecureRandom.urlsafe_base64(32), user_verified: true)
    relying_party = WebAuthn::RelyingParty.new(
      id: auth_host, allowed_origins: ["https://#{auth_host}"],
      encoding: :base64url,
    )
    public_credential = WebAuthn::Credential.from_create(registration, relying_party:)
    actor.client_passkeys.create!(
      webauthn_id: public_credential.id,
      public_key: public_credential.public_key,
      sign_count: 0,
    )
    client = OidcClientRegistry.find!("core-app-jp")
    now = OpAppGrant.database_now
    grant = OpAppGrant.create!(
      authentication_epoch: token.authentication_epoch,
      client_token: token,
      oidc_client_id: client.client_id,
      oidc_scope: "openid profile",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: SecureRandom.hex(16),
      oidc_auth_time: now - 1.hour,
      refresh_token_expires_at: now + 1.hour,
    )
    grant.issue_refresh_token!(expires_at: now + 1.hour, now:)
    authorization_params = {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
      scope: grant.oidc_scope,
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest("wu29-step-up"), padding: false),
      code_challenge_method: "S256",
      prompt: "login",
      claims: OidcAuthorizeRequestResolver::STEP_UP_CLAIMS,
    }
    validated_request = OidcAuthorizeRequestResolver.call(
      params: authorization_params,
      resource: actor,
      resource_type: "client",
    )
    issuance = OidcStepUpAuthorizationIssuer.call!(
      surface: "app",
      actor: actor,
      token: token,
      client: client,
      params: authorization_params,
      validated_request:,
    )

    assert_equal :issued, issuance.outcome

    binding = ClientAuthAdmissionBinding.find_by!(entry_ref: issuance.entry_ref)
    auth_session, raw_auth_sid = ClientAuthCeremonySession.issue!
    binding.attach_auth_session!(auth_session:, confirmation_ref: SecureRandom.uuid)

    auth = open_session
    auth.host!(auth_host)
    auth.https!
    sid_cookie = JitSessionCookieConfig.force_secure? ? "__Host-auth_sid" : "auth_sid"
    store_raw_cookies(
      auth.cookies,
      "#{sid_cookie}=#{Rack::Utils.escape(raw_auth_sid)}",
      URI.parse("https://#{auth_host}/"),
    )
    %w(in up).each do |flow|
      auth.get("/sign/#{flow}/sentry", params: { ri: "jp" })

      assert_equal 503, auth.response.status
      assert_equal "no-store", auth.response.headers["Cache-Control"]
    end

    visa = open_session
    visa.host!(visa_host)
    visa.https!
    visa.get("/health")
    session_key = Rails.application.config.session_options.fetch(:key)
    cookie_jar = ActionDispatch::Cookies::CookieJar.build(ActionDispatch::TestRequest.create, {})
    cookie_jar.encrypted[session_key] = { value: {
      "session_id" => SecureRandom.hex(16),
      "_csrf_token" => SecureRandom.urlsafe_base64(32),
      BaseAdmissionBrowserBinding::BROWSER_NONCE_SESSION_KEY => issuance.authorization_transaction.login_challenge,
    } }
    store_raw_cookies(
      visa.cookies,
      "#{session_key}=#{Rack::Utils.escape(cookie_jar[session_key])}",
      URI.parse("https://#{visa_host}/"),
    )
    visa.cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = AuthenticationToken.encode(
      actor,
      host: visa_host,
      session_public_id: token.public_id,
      resource_type: "client",
      jwt_issuer_id: "surface:VISA_APP",
    )
    confirmation_path = visa_app_ceremony_binding_confirmation_path(
      binding_ref: binding.confirmation_ref,
      ri: "jp",
    )
    navigation = { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }
    visa.get(confirmation_path, headers: navigation)

    assert_equal 303, visa.response.status
    assert_predicate binding.reload, :confirmed?
    assert_equal [token.id, actor.public_id], [binding.base_token_id, issuance.ticket.reload.actor_ref]
    verification_url = URI.parse(visa.response.location)

    assert_equal auth_host, verification_url.host
    assert_equal auth_app_verification_path(ri: "jp", entry_ref: issuance.entry_ref), verification_url.request_uri

    auth.get(verification_url.request_uri, headers: navigation.merge("Sec-Fetch-Site" => "cross-site"))

    assert_equal 303, auth.response.status
    assert_equal auth_app_verification_path(ri: "jp"), URI.parse(auth.response.location).request_uri
    auth.get(auth.response.location, headers: navigation)

    assert_equal 200, auth.response.status
    page = auth.response.parsed_body
    component = JSON.parse(page.at_css("script[data-page='app']").text)

    assert_equal "auth/app/verifications/show", component.fetch("component")
    assert_includes component.fetch("props").fetch("methods").map { |method| method.fetch("key") }, "passkey"
    binding.reload
    admitted_session = ClientAuthCeremonySession.find(binding.admitted_auth_ceremony_session_id)

    assert_predicate binding, :redeemed?
    assert_predicate admitted_session, :admitted?
  end
end
