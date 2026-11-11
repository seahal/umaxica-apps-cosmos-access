# typed: false
# frozen_string_literal: true

require "test_helper"

# A Jump configuration failure is a configuration error. A Visa OIDC authorization that hands the
# browser to Auth must never absorb a missing signing key or invalid issuer identity by downgrading
# to a same-host redirect.
class JumpConfigurationFailClosedTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  setup { @original_visa_service_url = ENV.fetch("PUBLIC_VISA_SERVICE_URL") }

  test "a sign-in handoff succeeds through Jump when configuration is valid" do
    visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    client = OidcClientRegistry.find!("core-app-jp")
    host! visa_host
    https!
    get "/oauth/authorize", params: {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
      scope: "openid profile",
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: OidcTestEntry::CODE_CHALLENGE,
      code_challenge_method: "S256",
    }

    assert_response :redirect
    location = URI.parse(response.location)
    rt = Rack::Utils.parse_query(location.query).fetch("rt")

    assert_equal "jump.umaxica.net", location.host
    assert_equal "https://#{visa_host}", JWT.decode(rt, nil, false).first.fetch("iss")
  end

  test "a missing Jump signing key raises instead of downgrading to a same-host redirect" do
    visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    client = OidcClientRegistry.find!("core-app-jp")
    host! visa_host
    https!

    JumpRtKeyring.stub(:private_key, nil) do
      assert_raises(JumpRtConfigurationError) do
        get "/oauth/authorize", params: {
          response_type: "code",
          client_id: client.client_id,
          redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
          scope: "openid profile",
          state: SecureRandom.urlsafe_base64(32),
          nonce: SecureRandom.urlsafe_base64(32),
          code_challenge: OidcTestEntry::CODE_CHALLENGE,
          code_challenge_method: "S256",
        }
      end
    end
  end

  test "runtime host mutation refuses the sign handoff without changing authority" do
    visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    client = OidcClientRegistry.find!("core-app-jp")
    host!(visa_host)
    https!

    ENV["PUBLIC_VISA_SERVICE_URL"] = "visa.app.localhost"
    assert_raises(JumpRtConfigurationError) do
      get(
        "/oauth/authorize", params: {
          response_type: "code",
          client_id: client.client_id,
          redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
          scope: "openid profile",
          state: SecureRandom.urlsafe_base64(32),
          nonce: SecureRandom.urlsafe_base64(32),
          code_challenge: OidcTestEntry::CODE_CHALLENGE,
          code_challenge_method: "S256",
        },
      )
    end
  ensure
    ENV["PUBLIC_VISA_SERVICE_URL"] = @original_visa_service_url
  end

  test "development Rails signs with its canonical issuer origin instead of rejecting it" do
    visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    client = OidcClientRegistry.find!("core-app-jp")
    host! visa_host
    https!
    get "/oauth/authorize", params: {
      response_type: "code",
      client_id: client.client_id,
      redirect_uri: client.redirect_uris_by_realm.fetch("client").first,
      scope: "openid profile",
      state: SecureRandom.urlsafe_base64(32),
      nonce: SecureRandom.urlsafe_base64(32),
      code_challenge: OidcTestEntry::CODE_CHALLENGE,
      code_challenge_method: "S256",
    }

    assert_response :redirect
    location = URI.parse(response.location)
    rt = Rack::Utils.parse_query(location.query).fetch("rt")

    assert_equal "jump.umaxica.net", location.host
    assert_equal "https://#{visa_host}", JWT.decode(rt, nil, false).first.fetch("iss")
  end
end
