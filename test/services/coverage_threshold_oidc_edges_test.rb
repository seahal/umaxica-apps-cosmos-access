# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcTokenExchangeRetainedBoundaryTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def service(**attributes)
    defaults = {
      grant_type: "refresh_token",
      refresh_token: "present-refresh-token",
      redirect_uri: "https://client.example.test/callback",
      client_id: "client",
      client_secret: nil,
      code_verifier: "v" * 43,
      client_assertion_type: nil,
      client_assertion: nil,
      dpop_proof: nil,
      token_endpoint_uri: nil,
      expected_resource_type: "client",
    }
    OidcTokenExchangeCoordinator.new(**defaults.merge(attributes))
  end

  test "refresh grant rejects missing credentials before resolving session state" do
    client = Struct.new(:registered_token_endpoint_auth_method).new("none")

    OidcClientRegistry.stub(:find, client) do
      missing = service(refresh_token: nil).call

      assert_equal "invalid_grant", missing.error
      assert_equal "refresh_token is required", missing.error_description
    end
  end

  test "unsupported grants and missing endpoint realm fail before client lookup" do
    OidcClientRegistry.stub(:find, ->(*) { flunk("invalid requests must not resolve a client") }) do
      unsupported = service(grant_type: "client_credentials").call

      assert_equal "invalid_request", unsupported.error
      assert_equal "grant_type must be 'authorization_code' or 'refresh_token'", unsupported.error_description

      missing_realm = service(expected_resource_type: nil).call

      assert_equal "invalid_request", missing_realm.error
      assert_equal "token endpoint realm is required", missing_realm.error_description
    end
  end

  test "private-key JWT refresh authentication refuses secrets and invalid assertions" do
    client = Struct.new(:registered_token_endpoint_auth_method).new("private_key_jwt")
    invalid_assertion = OidcClientRegistry::AssertionAuthenticationResult.new(
      authenticated: false, client: nil, step_up_claims_state: :none, step_up_expectation: nil,
    )

    OidcClientRegistry.stub(:find, client) do
      secret_result = service(
        client_secret: "unexpected-secret",
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: "assertion",
        token_endpoint_uri: "https://issuer.example.test/oauth/token",
      ).call

      assert_equal "invalid_client", secret_result.error

      OidcClientRegistry.stub(:verify_client_assertion, invalid_assertion) do
        assertion_result = service(
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
          client_assertion: "invalid-assertion",
          token_endpoint_uri: "https://issuer.example.test/oauth/token",
        ).call

        assert_equal "invalid_client", assertion_result.error
        assert_nil assertion_result.token_response
      end
    end
  end
end
