# typed: false
# frozen_string_literal: true

require "test_helper"

class JumpRtSurfaceIdentityTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "only Auth and Visa have Jump issuer capabilities" do
    expected = {
      "AUTH_APP" => "PUBLIC_AUTH_SERVICE_URL",
      "AUTH_ORG" => "PUBLIC_AUTH_STAFF_URL",
      "VISA_APP" => "PUBLIC_VISA_SERVICE_URL",
      "VISA_ORG" => "PUBLIC_VISA_STAFF_URL",
    }

    assert_equal expected, JumpRtSurface::ISSUER_ORIGIN_ENV
    assert_equal expected.keys.sort, JumpRtSurface::ISSUER_NAMESPACES.sort
  end

  test "external RP origins remain return destinations without issuer capabilities" do
    expected = JumpRtSurface::ISSUER_ORIGIN_ENV.merge(
      "BASE_APP" => "PUBLIC_BASE_SERVICE_URL",
      "BASE_ORG" => "PUBLIC_BASE_STAFF_URL",
      "CORE_APP" => "PUBLIC_CORE_SERVICE_URL",
      "CORE_ORG" => "PUBLIC_CORE_STAFF_URL",
      "WARP_APP" => "PUBLIC_WARP_SERVICE_URL",
      "WARP_ORG" => "PUBLIC_WARP_STAFF_URL",
      "PALM_APP" => "PUBLIC_PALM_SERVICE_URL",
    )

    assert_equal expected, JumpRtSurface::RETURN_ORIGIN_ENV
    %w(BASE_APP BASE_ORG CORE_APP CORE_ORG WARP_APP WARP_ORG PALM_APP EDIT_ORG TECH_ORG).each do |namespace|
      assert_raises(JumpRtConfigurationError, namespace) { JumpRtSurface.normalize_issuer_namespace(namespace) }
    end
  end

  test "Auth and Visa controllers resolve to active Jump issuer namespaces" do
    assert_equal "AUTH_APP", JumpRtSurface.namespace_for_controller("Auth::App::SignInsController")
    assert_equal "AUTH_ORG", JumpRtSurface.namespace_for_controller("Auth::Org::SignInsController")
    assert_equal "VISA_APP", JumpRtSurface.namespace_for_controller("Visa::App::Oauth::AuthorizationsController")
    assert_equal "VISA_ORG", JumpRtSurface.namespace_for_controller("Visa::Org::Sign::ByesController")
    assert_raises(JumpRtConfigurationError) do
      JumpRtSurface.namespace_for_controller("Visa::Com::Oauth::TokensController")
    end
  end

  test "issuer and JWKS use the Access origin while RP returns use the registered RP origin" do
    env = {
      "PUBLIC_AUTH_SERVICE_URL" => "auth.umaxica.app",
      "PUBLIC_BASE_SERVICE_URL" => "www.umaxica.app",
    }

    assert_equal "https://auth.umaxica.app", JumpRtSurface.issuer_origin("AUTH_APP", env:)
    assert_equal "https://auth.umaxica.app/.well-known/jwks.json", JumpRtSurface.issuer_jwks_uri("AUTH_APP", env:)
    assert_equal "https://www.umaxica.app", JumpRtSurface.return_origin("BASE_APP", env:)
  end

  test "an explicit https scheme on a Visa origin is accepted" do
    env = { "PUBLIC_VISA_SERVICE_URL" => "https://visa-jp.umaxica.app" }

    assert_equal "https://visa-jp.umaxica.app", JumpRtSurface.issuer_origin("VISA_APP", env:)
  end

  test "missing Access issuer origin fails closed and names the setting" do
    error = assert_raises(JumpRtConfigurationError) { JumpRtSurface.issuer_origin("AUTH_ORG", env: {}) }

    assert_match(/PUBLIC_AUTH_STAFF_URL/, error.message)
  end

  {
    "blank" => "",
    "zero sentinel" => "0",
    "NUL character" => "auth.umaxica.app\u0000",
    "control character" => "auth.umaxica.app\n",
    "http scheme" => "http://auth.umaxica.app",
    "malformed" => "https://auth umaxica app",
    "localhost" => "localhost",
    "localhost subdomain" => "auth.app.localhost",
    "local suffix" => "auth.local",
    "internal suffix" => "auth.internal",
    "private IPv4 literal" => "192.168.1.1",
    "loopback IPv4 literal" => "127.0.0.1",
    "link-local IPv4 literal" => "169.254.1.1",
    "loopback IPv6 literal" => "https://[::1]",
    "userinfo" => "https://user@auth.umaxica.app",
    "path" => "https://auth.umaxica.app/auth",
    "query" => "https://auth.umaxica.app?x=1",
    "fragment" => "https://auth.umaxica.app#x",
    "port" => "https://auth.umaxica.app:3000",
  }.each do |label, raw|
    test "PUBLIC_* Jump issuer origin rejects #{label}" do
      assert_raises(JumpRtConfigurationError) do
        JumpRtSurface.issuer_origin("AUTH_APP", env: { "PUBLIC_AUTH_SERVICE_URL" => raw })
      end
    end
  end

  test "development can present canonical public Auth and Visa issuer origins" do
    canonical = {
      "AUTH_APP" => "auth.umaxica.app",
      "AUTH_ORG" => "auth.umaxica.org",
      "VISA_APP" => "visa.umaxica.app",
      "VISA_ORG" => "visa.umaxica.org",
    }

    Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new("development")) do
      canonical.each do |namespace, host|
        env = { JumpRtSurface::ISSUER_ORIGIN_ENV.fetch(namespace) => host }

        assert_equal "https://#{host}", JumpRtSurface.issuer_origin(namespace, env:), namespace
      end
    end
  end

  test "issuer origin validation is identical in every Rails environment" do
    %w(development test production).each do |name|
      Rails.stub(:env, ActiveSupport::EnvironmentInquirer.new(name)) do
        assert_equal "https://auth.umaxica.app",
                     JumpRtSurface.issuer_origin("AUTH_APP", env: { "PUBLIC_AUTH_SERVICE_URL" => "auth.umaxica.app" }),
                     name
        assert_raises(JumpRtConfigurationError, name) do
          JumpRtSurface.issuer_origin("AUTH_APP", env: { "PUBLIC_AUTH_SERVICE_URL" => "auth.app.localhost" })
        end
      end
    end
  end
end
