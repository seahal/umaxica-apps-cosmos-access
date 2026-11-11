# typed: false
# frozen_string_literal: true

require "test_helper"

class AcceptanceWu02JwksSeparationTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "A02-6: Visa and Auth JWKS have disjoint kids and public key material in every realm" do
    realms = [
      %w(app PUBLIC_VISA_SERVICE_URL PUBLIC_AUTH_SERVICE_URL VISA_APP AUTH_APP),
      %w(org PUBLIC_VISA_STAFF_URL PUBLIC_AUTH_STAFF_URL VISA_ORG AUTH_ORG),
    ]

    realms.each do |realm, visa_host_key, auth_host_key, visa_namespace, auth_namespace|
      visa_browser = open_session
      visa_browser.https!
      visa_browser.host!(ENV.fetch(visa_host_key))
      visa_browser.get("/.well-known/jwks.json")

      assert_equal 200, visa_browser.response.status, "Visa #{realm} JWKS request"
      visa_keys = visa_browser.response.parsed_body.fetch("keys")

      auth_browser = open_session
      auth_browser.https!
      auth_browser.host!(ENV.fetch(auth_host_key))
      auth_browser.get("/.well-known/jwks.json")

      assert_equal 200, auth_browser.response.status, "Auth #{realm} JWKS request"
      auth_keys = auth_browser.response.parsed_body.fetch("keys")

      assert_includes visa_keys.map { |key| key.fetch("kid") },
                      JitSecurityJwtRegistry.surface(visa_namespace).current_kid,
                      "Visa #{realm} JWKS must publish the Visa issuer's active key"
      assert_includes auth_keys.map { |key| key.fetch("kid") },
                      JitSecurityJwtRegistry.surface(auth_namespace).current_kid,
                      "Auth #{realm} JWKS must publish the Auth issuer's active key"
      assert_empty visa_keys.map { |key| key.fetch("kid") } & auth_keys.map { |key| key.fetch("kid") },
                   "Visa and Auth #{realm} JWKS must not share a kid"

      visa_material = visa_keys.map { |key| key.slice("kty", "crv", "x", "y") }
      auth_material = auth_keys.map { |key| key.slice("kty", "crv", "x", "y") }

      assert_empty visa_material & auth_material,
                   "Visa and Auth #{realm} JWKS must not share public key material"
    end
  end
end
