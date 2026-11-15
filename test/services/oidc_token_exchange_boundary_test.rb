# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class OidcTokenExchangeBoundaryTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "authenticated authorization code exchange is explicitly unavailable without transaction facts" do
    client = Struct.new(:registered_token_endpoint_auth_method, :authorization_response_type).new("none", "code")

    OidcClientRegistry.stub(:find, client) do
      result = OidcTokenExchangeCoordinator.call(
        grant_type: "authorization_code",
        code: "unconsumed-code",
        client_id: "public-client",
        expected_resource_type: "client",
      )

      assert_not result.success?
      assert_equal "temporarily_unavailable", result.error
      assert_equal "authorization-code issuance is unavailable for this client", result.error_description
      assert_nil result.token_response
    end
  end

  test "Base clients cannot receive tokens from either Token Endpoint grant" do
    %w(base-app-ww base-org-ww).each do |client_id|
      client = OidcClientRegistry.find!(client_id)
      assertion_result = OidcClientRegistry::AssertionAuthenticationResult.new(
        authenticated: true,
        client: client,
        step_up_claims_state: :none,
        step_up_expectation: nil,
      )

      OidcClientRegistry.stub(:verify_client_assertion, assertion_result) do
        [
          { grant_type: "authorization_code", code: "unredeemed-code" },
          { grant_type: "refresh_token", refresh_token: "unredeemed-refresh-token" },
        ].each do |grant|
          result = OidcTokenExchangeCoordinator.call(
            **grant,
            client_id: client_id,
            client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
            client_assertion: "verified-assertion",
            token_endpoint_uri: OidcIssuer.token_endpoint(client.resource_type),
            expected_resource_type: client.resource_type,
          )

          assert_not result.success?, "#{client_id} #{grant.fetch(:grant_type)} must fail closed"
          assert_equal "unauthorized_client", result.error
          assert_equal "Base front-channel clients do not use the Token Endpoint", result.error_description
          assert_nil result.token_response
        end
      end
    end
  end

  test "token exchange service does not mint actor-root sessions" do
    source = Rails.root.join("app/services/oidc_token_exchange_coordinator.rb").read

    assert_no_match(/ClientToken\.create!?/, source)
    assert_no_match(/OperatorToken\.create!?/, source)
    assert_no_match(/create_login_token_record/, source)
    assert_no_match(/\blog_in\b/, source)
  end

  test "token exchange service does not rotate the root refresh token directly" do
    source = Rails.root.join("app/services/oidc_token_exchange_coordinator.rb").read

    assert_no_match(/root_token\.rotate_refresh_token!/, source)
  end

  test "private-key JWT authentication requires the token endpoint URI" do
    result = OidcTokenExchangeCoordinator.call(
      grant_type: "authorization_code",
      code: "unused-code",
      client_id: "core-app-jp",
      client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
      client_assertion: "unverified-assertion",
      expected_resource_type: "client",
    )

    assert_not result.success?
    assert_equal "invalid_client", result.error
    assert_nil result.token_response
  end

  test "private-key JWT authentication requires an assertion" do
    result = OidcTokenExchangeCoordinator.call(
      grant_type: "authorization_code",
      code: "unused-code",
      client_id: "core-app-jp",
      client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
      token_endpoint_uri: OidcIssuer.token_endpoint("client"),
      expected_resource_type: "client",
    )

    assert_not result.success?
    assert_equal "invalid_client", result.error
    assert_nil result.token_response
  end

  test "client authentication refuses unknown clients and credentials on public clients" do
    unknown = OidcTokenExchangeCoordinator.call(
      grant_type: "authorization_code",
      code: "unused-code",
      client_id: "unregistered-test-client",
      expected_resource_type: "client",
    )

    assert_equal "invalid_client", unknown.error

    public_client = Struct.new(:registered_token_endpoint_auth_method, :authorization_response_type).new("none", "code")
    credential_sets = [
      { client_secret: "unexpected-secret" },
      { client_assertion: "unexpected-assertion" },
      { client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE },
    ]

    OidcClientRegistry.stub(:find, public_client) do
      credential_sets.each do |credentials|
        result = OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code",
          code: "unused-code",
          client_id: "public-client",
          expected_resource_type: "client",
          **credentials,
        )

        assert_equal "invalid_client", result.error, credentials.inspect
        assert_nil result.token_response, credentials.inspect
      end
    end
  end

  test "refresh exchange rejects unresolved and mismatched token ownership before rotation" do
    client = Struct.new(:registered_token_endpoint_auth_method, :authorization_response_type).new("none", "code")
    mismatched_client = Struct.new(:usage).new(Struct.new(:oidc_client_id).new("another-client"))
    unsupported_usage = Struct.new(:usage).new(Struct.new(:oidc_client_id).new("public-client"))

    OidcClientRegistry.stub(:find, client) do
      [
        [nil, "refresh token not found"],
        [mismatched_client, "refresh token is not bound to this client"],
        [unsupported_usage, "refresh token realm mismatch"],
      ].each do |resolved, description|
        OidcRefreshTokenIssuer.stub(:resolve, resolved) do
          result = OidcTokenExchangeCoordinator.call(
            grant_type: "refresh_token",
            refresh_token: "present-refresh-token",
            client_id: "public-client",
            expected_resource_type: "client",
          )

          assert_equal "invalid_grant", result.error, description
          assert_equal description, result.error_description
          assert_nil result.token_response
        end
      end
    end
  end
end
