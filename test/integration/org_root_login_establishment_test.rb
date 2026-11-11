# frozen_string_literal: true

require "test_helper"
require "webauthn/fake_client"

class OrgRootLoginEstablishmentTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  teardown do
    TurnstileVerifierStub.enabled = false
    TurnstileVerifierStub.response = nil
  end

  # Provider HTTP is simulated; state, nonce, JWT signature, WebAuthn and Visa issuance are real.
  test "Entra and Passkey establish Normal root credentials only on Visa" do
    operator = Operator.create!(security_mode_id: SecurityModeConfigurable::ADVANCED)
    tenant = SecureRandom.uuid
    audience = SecureRandom.uuid
    object_id = SecureRandom.uuid
    issuer = "https://login.microsoftonline.com/#{tenant}/v2.0"
    OperatorEntraIdentityState.ensure_defaults!
    identity = OperatorEntraIdentity.create!(
      operator_id: operator.id, entra_tenant_id: tenant, entra_object_id: object_id,
      status_id: OperatorEntraIdentityState::ACTIVE,
    )
    auth_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    private_auth_host = ENV.fetch("PRIVATE_AUTH_STAFF_URL")
    visa_host = ENV.fetch("PUBLIC_VISA_STAFF_URL")
    private_visa_host = ENV.fetch("PRIVATE_VISA_STAFF_URL")
    auth_hosts = [auth_host, private_auth_host].uniq
    visa_hosts = [visa_host, private_visa_host].uniq
    fake = WebAuthn::FakeClient.new("https://#{auth_host}", encoding: :base64url)
    registration = fake.create(challenge: SecureRandom.urlsafe_base64(32), user_verified: true)
    relying_party = WebAuthn::RelyingParty.new(
      id: auth_host, allowed_origins: [fake.origin], encoding: :base64url,
    )
    credential = WebAuthn::Credential.from_create(registration, relying_party: relying_party)
    operator.staff_passkeys.create!(webauthn_id: credential.id, public_key: credential.public_key, sign_count: 0)
    # ORG ADVANCED Root sessions require two active Passkeys before other Base pages are reachable.
    operator.staff_passkeys.create!(
      webauthn_id: "org_root_step_up_#{SecureRandom.hex(16)}",
      public_key: "org-root-step-up-public-key",
      sign_count: 0,
    )
    JitSecurityJwtRegistry.surface("VISA_ORG")
    jump_host = URI.parse(Rails.configuration.x.boot_config.fetch(:jump).origin.to_s).host
    https!
    host!(visa_host)
    client = OidcClientRegistry.find!("core-org-jp")
    get(
      "/oauth/authorize", params: {
        response_type: "code",
        client_id: client.client_id,
        redirect_uri: client.redirect_uris_by_realm.fetch("operator").first,
        scope: "openid profile",
        state: SecureRandom.urlsafe_base64(32),
        nonce: SecureRandom.urlsafe_base64(32),
        code_challenge: OidcTestEntry::CODE_CHALLENGE,
        code_challenge_method: "S256",
      }, headers: oidc_navigation_headers(visa_host),
    )

    assert_equal 303, response.status
    target = URI.parse(jump_rt_url_from_location_for_test(response.location))
    auth_browser = open_session
    current_host = target.host
    current_browser =
      case current_host
      when *visa_hosts then self
      when *auth_hosts then auth_browser
      else raise RuntimeError, "unexpected OIDC admission host: #{current_host.inspect}"
      end
    entry_ref = nil
    12.times do
      current_browser.host!(current_host)
      current_browser.https!
      current_browser.get(target.request_uri, headers: oidc_navigation_headers(current_host))
      break unless current_browser.response.redirect?

      target = URI.parse(current_browser.response.location.to_s)
      target = URI.parse("https://#{current_host}#{target}") if target.host.blank?
      target = URI.parse(jump_rt_url_from_location_for_test(target.to_s)) if target.host == jump_host
      entry_ref ||= Rack::Utils.parse_query(target.query)["entry_ref"] if target.query.to_s.present?
      current_host = target.host
      current_browser =
        case current_host
        when *visa_hosts then self
        when *auth_hosts then auth_browser
        else raise RuntimeError, "unexpected OIDC admission host: #{current_host.inspect}"
        end
    end

    unless current_browser.equal?(auth_browser) && auth_browser.response.successful?
      raise RuntimeError,
            "OIDC admission did not reach Auth (host=#{current_host}, path=#{target.path}, " \
            "status=#{current_browser.response.status})"
    end

    raise RuntimeError, "OIDC admission entry reference is missing" if entry_ref.blank?

    binding = BaseAuthAdmissionCoordinator.find_admission_binding!(surface: "org", reference: entry_ref)
    flow = authorization_transaction_for_test(binding)

    assert_predicate binding.reload, :redeemed?
    previous_test_mode = OmniAuth.config.test_mode
    OmniAuth.config.test_mode = false
    registry = ExternalAuthentication::ProviderRegistry
    registry.stub(:tenant_id, tenant) do
      registry.stub(:audience, audience) do
        registry.stub(:issuer_for, issuer) do
          auth_browser.post("/social/entra", params: { ri: "jp" })

          assert_equal 302, auth_browser.response.status
          query = Rack::Utils.parse_nested_query(URI.parse(auth_browser.response.location).query)

          assert_equal "S256", query.fetch("code_challenge_method")
          key = OpenSSL::PKey::RSA.generate(2048)
          kid = SecureRandom.hex(8)
          jwk = JWT::JWK.new(key, { "kid" => kid })
          now = Time.current.to_i
          id_token = JWT.encode(
            { "iss" => issuer,
              "aud" => audience,
              "tid" => tenant,
              "oid" => object_id,
              "sub" => "pairwise-#{operator.public_id}",
              "acct" => 0,
              "ver" => "2.0",
              "nonce" => query.fetch("nonce"),
              "iat" => now,
              "exp" => now + 3600, },
            key, "RS256", { "kid" => kid },
          )
          token_stubs =
            Faraday::Adapter::Test::Stubs.new do |stub|
              stub.post("/#{tenant}/oauth2/v2.0/token") do
                [200, { "Content-Type" => "application/json" },
                 JSON.generate(
                   access_token: "offline-access-token", token_type: "Bearer", expires_in: 3600,
                   id_token: id_token,
                 ),]
              end
            end
          token_http =
            Faraday.new(url: "https://login.microsoftonline.com") do |http|
              http.request(:url_encoded)
              http.response(:json)
              http.adapter(:test, token_stubs)
            end
          jwks_stubs =
            Faraday::Adapter::Test::Stubs.new do |stub|
              stub.get("/#{tenant}/discovery/v2.0/keys") do
                [200, { "Content-Type" => "application/json" }, JSON.generate(keys: [jwk.export])]
              end
            end
          jwks_http = Faraday.new(url: "https://login.microsoftonline.com") { |http| http.adapter(:test, jwks_stubs) }
          Rack::OAuth2.stub(:http_client, token_http) do
            OutboundHttp::Connection.stub(:build, jwks_http) do
              Rails.stub(:cache, ActiveSupport::Cache::MemoryStore.new) do
                TestSupport::OutboundHttpGuard.allow do
                  auth_browser.get(
                    "/social/entra/callback",
                    params: { state: query.fetch("state"), code: "offline-code" },
                  )
                end
              end
            end
          end
          token_stubs.verify_stubbed_calls
          jwks_stubs.verify_stubbed_calls
        end
      end
    end

    assert_equal 303, auth_browser.response.status
    passkey_binding = Rack::Utils.parse_nested_query(
      URI.parse(auth_browser.response.location).query.to_s,
    ).fetch("fb")

    assert_not_nil identity.reload.last_authenticated_at
    assert_equal 0, OperatorToken.where(staff_id: operator.id).count
    TurnstileVerifierStub.enabled = true
    TurnstileVerifierStub.response = { "success" => true }
    auth_browser.post(
      auth_org_sign_in_passkey_options_path(fb: passkey_binding, ri: "jp"),
      params: { "cf-turnstile-response" => "t" },
    )

    assert_equal 200, auth_browser.response.status
    options = auth_browser.response.parsed_body
    assertion = fake.get(challenge: options.fetch("options").fetch("challenge"), user_verified: true, sign_count: 2)
    auth_browser.post(
      auth_org_sign_in_passkey_verification_path(fb: passkey_binding, ri: "jp"),
      params: { credential: assertion, challenge_id: options.fetch("challenge_id") }, as: :json,
    )

    assert_equal 200, auth_browser.response.status
    assert_equal "ok", auth_browser.response.parsed_body.fetch("status")
    assert_no_difference(-> { OperatorToken.where(staff_id: operator.id).count }) do
      auth_browser.get(auth_browser.response.parsed_body.fetch("redirect_url"))
      auth_browser.follow_redirect!
      auth_browser.get(
        auth_org_sign_oidc_handoff_path(ri: "jp"),
        headers: oidc_navigation_headers(auth_host),
      )
    end

    assert_equal 303, auth_browser.response.status
    assert_nil auth_browser.cookies[AuthenticationBase::ACCESS_COOKIE_KEY]
    assert_nil auth_browser.cookies[AuthenticationBase::REFRESH_COOKIE_KEY]
    target = URI.parse(jump_rt_url_from_location_for_test(auth_browser.response.location))
    host!(visa_host)
    token_count_before_resume = OperatorToken.where(staff_id: operator.id).count
    get(target.request_uri, headers: oidc_navigation_headers(visa_host))

    assert_equal 200, response.status, response.body
    continuation_form = response.parsed_body.at_css("form#visa-authorization-continuation-form")

    assert continuation_form, "Visa result GET must render its same-origin POST continuation"
    continuation_fields =
      continuation_form.css("input[type='hidden']").to_h do |input|
        [input["name"], input["value"]]
      end
    post(
      continuation_form["action"],
      params: continuation_fields,
      headers: oidc_navigation_headers(visa_host).merge(
        "Origin" => OidcIssuer.absolute_url(visa_host),
        "Sec-Fetch-Site" => "same-origin",
      ),
    )

    assert_equal 303, response.status, response.body
    assert_equal token_count_before_resume + 1, OperatorToken.where(staff_id: operator.id).count
    token = OperatorToken.find_by!(staff_id: operator.id)

    assert_equal AuthenticationContextValue::NORMAL_KEY, token.authentication_context
    assert_not_nil token.root_login_established_at
    assert_predicate flow.reload, :consumed?
    assert_equal token.public_id, flow.browser_session_ref
    assert_predicate cookies[AuthenticationBase::ACCESS_COOKIE_KEY].to_s, :present?
    established_at = token.root_login_established_at
    callback_uri = URI.parse(jump_rt_url_from_location_for_test(response.location))
    expected_callback = URI.parse(client.redirect_uris_by_realm.fetch("operator").first)

    assert_equal [expected_callback.host, expected_callback.path], [callback_uri.host, callback_uri.path]
    assert_no_difference(-> { OperatorToken.where(staff_id: operator.id).count }) do
      get(target.request_uri, headers: oidc_navigation_headers(visa_host))
    end
    assert_response :bad_request
    assert_equal established_at, token.reload.root_login_established_at
    assert_equal 1, OperatorToken.where(staff_id: operator.id).count
  ensure
    OmniAuth.config.test_mode = previous_test_mode unless previous_test_mode.nil?
  end

  private

  def oidc_navigation_headers(host)
    {
      "Host" => host,
      "Sec-Fetch-Mode" => "navigate",
      "Sec-Fetch-Dest" => "document",
      "Sec-Fetch-Site" => "cross-site",
    }
  end
end
