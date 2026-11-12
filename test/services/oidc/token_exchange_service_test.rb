# frozen_string_literal: true

require "test_helper"

class OidcExistingGrantRefreshCoordinatorTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(client_tokens operator_tokens client_device_sessions operator_device_sessions)

  setup do
    @root = ClientToken.includes(:device_session).find(ActiveRecord::FixtureSet.identify(:one))
    @client = OidcClientRegistry.find!("core-app-jp")
    @grant = OpAppGrant.create!(
      authentication_epoch: @root.authentication_epoch,
      device_session_id: @root.device_session_id,
      client_token_id: @root.id,
      oidc_client_id: @client.client_id,
      oidc_jti: SecureRandom.uuid,
      oidc_scope: "openid profile",
      oidc_auth_time: Time.current,
      oidc_acr: "aal1",
      oidc_amr: '["pwd"]',
      oidc_nonce: "existing-nonce",
      refresh_token_expires_at: 1.hour.from_now,
    )
    @assertion = OidcClientRegistry::AssertionAuthenticationResult.new(
      authenticated: true, client: @client, step_up_claims_state: :none, step_up_expectation: nil,
    )
  end

  test "authenticated authorization code exchange is unavailable without consuming an existing code" do
    store = Valkey::AuthState::AuthorizationCodeStore.new
    code = store.issue!(
      client_id: @client.client_id, redirect_uri: @client.redirect_uris.first,
      subject: "cli_#{@root.device_session.principal_public_id}", base_session_ref: @root.public_id,
      code_challenge: "a" * 43, code_challenge_method: "S256", resource_type: "client",
    )
    grant_before = @grant.reload.attributes
    result =
      OidcClientRegistry.stub(:verify_client_assertion, @assertion) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code", code: code, client_id: @client.client_id,
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE, client_assertion: "verified-assertion",
          token_endpoint_uri: OidcIssuer.token_endpoint("client"), expected_resource_type: "client",
        )
      end

    assert_not_predicate result, :success?
    assert_equal "temporarily_unavailable", result.error
    assert_nil result.token_response
    assert_equal "issued", store.read(code).fetch("state")
    assert_equal grant_before, @grant.reload.attributes
  end

  test "fails for wrong grant_type" do
    result = OidcTokenExchangeCoordinator.call(
      grant_type: "implicit", client_id: @client.client_id, expected_resource_type: "client",
    )

    assert_not result.success?
    assert_equal "invalid_request", result.error
  end

  test "fails for wrong client_secret_credential" do
    result = OidcTokenExchangeCoordinator.call(
      grant_type: "authorization_code", code: "unconsumed-code", client_id: @client.client_id,
      client_secret: "wrong_secret_credential", expected_resource_type: "client",
    )

    assert_not result.success?
    assert_equal "invalid_client", result.error
  end

  test "fails invalid_client for missing confidential client secret" do
    result = OidcTokenExchangeCoordinator.call(
      grant_type: "authorization_code", code: "unconsumed-code", client_id: @client.client_id,
      expected_resource_type: "client",
    )

    assert_not result.success?
    assert_equal "invalid_client", result.error
  end

  test "an unregistered content-like client does not enable public token exchange" do
    result = OidcTokenExchangeCoordinator.call(
      grant_type: "authorization_code", code: "unconsumed-code", client_id: "retired-content-client",
      expected_resource_type: "client",
    )

    assert_not result.success?
    assert_equal "invalid_client", result.error
  end

  test "rejects private_key_jwt client assertion with wrong token endpoint audience" do
    endpoint = OidcIssuer.token_endpoint("client")
    assertion = OidcClientAssertionJwt.issue(client_id: @client.client_id, token_url: endpoint)
    result = OidcTokenExchangeCoordinator.call(
      grant_type: "authorization_code", code: "unconsumed-code", client_id: @client.client_id,
      client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE, client_assertion: assertion,
      token_endpoint_uri: "#{endpoint}-alt", expected_resource_type: "client",
    )

    assert_not result.success?
    assert_equal "invalid_client", result.error
  end

  test "rejects reused private_key_jwt client assertion before another exchange" do
    endpoint = OidcIssuer.token_endpoint("client")
    assertion = OidcClientAssertionJwt.issue(client_id: @client.client_id, token_url: endpoint)
    first = OidcTokenExchangeCoordinator.call(
      grant_type: "authorization_code", code: "unconsumed-code", client_id: @client.client_id,
      client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE, client_assertion: assertion,
      token_endpoint_uri: endpoint, expected_resource_type: "client",
    )
    second = OidcTokenExchangeCoordinator.call(
      grant_type: "authorization_code", code: "other-unconsumed-code", client_id: @client.client_id,
      client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE, client_assertion: assertion,
      token_endpoint_uri: endpoint, expected_resource_type: "client",
    )

    assert_equal "temporarily_unavailable", first.error
    assert_not second.success?
    assert_equal "invalid_client", second.error
  end

  test "rejects client assertion unless private_key_jwt is explicitly registered" do
    client = Struct.new(:registered_token_endpoint_auth_method).new(nil)
    result =
      OidcClientRegistry.stub(:find, client) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code", code: "unconsumed-code", client_id: @client.client_id,
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE, client_assertion: "assertion",
          token_endpoint_uri: OidcIssuer.token_endpoint("client"), expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "invalid_client", result.error
  end

  test "rejects private_key_jwt client when client_secret is supplied instead of assertion" do
    result = OidcTokenExchangeCoordinator.call(
      grant_type: "authorization_code", code: "unconsumed-code", client_id: @client.client_id,
      client_secret: "unexpected-secret", expected_resource_type: "client",
    )

    assert_not result.success?
    assert_equal "invalid_client", result.error
  end

  test "rejects client_secret_post client when an assertion is supplied" do
    client = Struct.new(:registered_token_endpoint_auth_method).new("client_secret_post")
    result =
      OidcClientRegistry.stub(:find, client) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code", code: "unconsumed-code", client_id: @client.client_id,
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE, client_assertion: "assertion",
          token_endpoint_uri: OidcIssuer.token_endpoint("client"), expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "invalid_client", result.error
  end

  test "diagnostic metadata none does not enable public token exchange" do
    client = Struct.new(:registered_token_endpoint_auth_method, :metadata_token_endpoint_auth_method, :client_secret)
      .new(nil, "none", nil)
    result =
      OidcClientRegistry.stub(:find, client) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code", code: "unconsumed-code", client_id: "metadata_none_test",
          expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "invalid_client", result.error
  end

  test "explicit public client rejects client_secret authentication" do
    client = Struct.new(:registered_token_endpoint_auth_method).new("none")
    result =
      OidcClientRegistry.stub(:find, client) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code", code: "unconsumed-code", client_id: "public_test",
          client_secret: "unexpected-secret", expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "invalid_client", result.error
  end

  test "explicit public client rejects client assertion authentication" do
    client = Struct.new(:registered_token_endpoint_auth_method).new("none")
    result =
      OidcClientRegistry.stub(:find, client) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code", code: "unconsumed-code", client_id: "public_test",
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE, client_assertion: "assertion",
          token_endpoint_uri: OidcIssuer.token_endpoint("client"), expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "invalid_client", result.error
  end

  test "refresh grant refuses to extend a root with an unbounded expiry" do
    refresh_token = @grant.issue_refresh_token!
    original_digest = @grant.refresh_token_digest
    original_generation = @grant.refresh_generation
    @root.update!(discard_at: Float::INFINITY, purge_eligible_at: Float::INFINITY)
    result =
      OidcClientRegistry.stub(:verify_client_assertion, @assertion) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "refresh_token", refresh_token: refresh_token, client_id: @client.client_id,
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE, client_assertion: "verified-assertion",
          token_endpoint_uri: OidcIssuer.token_endpoint("client"), expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "invalid_grant", result.error
    assert_equal original_digest, @grant.reload.refresh_token_digest
    assert_equal original_generation, @grant.refresh_generation
  end

  test "refresh grant rotates the RP refresh token and reissues tokens with the original auth time" do
    authentication_event_at = Time.utc(2026, 1, 2, 3, 4, 5)
    @grant.update!(oidc_auth_time: authentication_event_at)
    initial_refresh = @grant.issue_refresh_token!
    refreshed_result =
      OidcClientRegistry.stub(:verify_client_assertion, @assertion) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "refresh_token", refresh_token: initial_refresh, client_id: @client.client_id,
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE, client_assertion: "verified-assertion",
          token_endpoint_uri: OidcIssuer.token_endpoint("client"), expected_resource_type: "client",
        )
      end

    assert_predicate initial_refresh, :present?
    assert_predicate refreshed_result, :success?
    assert_predicate refreshed_result.token_response[:access_token], :present?
    assert_predicate refreshed_result.token_response[:refresh_token], :present?
    assert_predicate refreshed_result.token_response[:id_token], :present?
    assert_not_equal initial_refresh, refreshed_result.token_response.fetch(:refresh_token)
    access_payload = AuthenticationTokenService.decode(
      refreshed_result.token_response.fetch(:access_token),
      host: OidcIssuer.host_for_client(@client),
      resource_type: "client",
      issuer: OidcIssuer.for_client(@client),
      audiences: [@client.aud],
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(@client),
    )
    id_payload = JWT.decode(refreshed_result.token_response.fetch(:id_token), nil, false).first

    assert_equal authentication_event_at.to_i, access_payload.fetch("auth_time")
    assert_equal authentication_event_at.to_i, id_payload.fetch("auth_time")
    assert_operator access_payload.fetch("iat"), :>, authentication_event_at.to_i
  end

  test "refreshed OIDC access id and refresh tokens end by the root session expiry" do
    absolute_expiry = 2.minutes.from_now
    @root.update!(discard_at: absolute_expiry)
    @grant.update!(refresh_token_expires_at: absolute_expiry)
    refresh_token = @grant.issue_refresh_token!
    result =
      OidcClientRegistry.stub(:verify_client_assertion, @assertion) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "refresh_token", refresh_token: refresh_token, client_id: @client.client_id,
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE, client_assertion: "verified-assertion",
          token_endpoint_uri: OidcIssuer.token_endpoint("client"), expected_resource_type: "client",
        )
      end

    assert_predicate result, :success?
    access_token = AuthenticationTokenService.decode(
      result.token_response.fetch(:access_token),
      host: OidcIssuer.host_for_client(@client), resource_type: "client", issuer: OidcIssuer.for_client(@client),
      audiences: [@client.aud], jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(@client),
    )
    id_token = JWT.decode(result.token_response.fetch(:id_token), nil, false).first

    assert_operator Time.zone.at(access_token.fetch("exp")), :<=, absolute_expiry
    assert_operator Time.zone.at(id_token.fetch("exp")), :<=, absolute_expiry
    assert_operator result.token_response.fetch(:expires_in), :<=, (absolute_expiry - Time.current).to_i
    assert_operator @grant.reload.refresh_token_expires_at, :<=, absolute_expiry
  end

  test "does not fall back to Bearer after a failed established DPoP constraint on refresh" do
    @grant.update!(dpop_jkt: SecureRandom.urlsafe_base64(32, padding: false))
    refresh_token = @grant.issue_refresh_token!
    refresh_digest = @grant.refresh_token_digest
    result =
      OidcClientRegistry.stub(:verify_client_assertion, @assertion) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "refresh_token", refresh_token: refresh_token, client_id: @client.client_id,
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE, client_assertion: "verified-assertion",
          token_endpoint_uri: OidcIssuer.token_endpoint("client"), expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "invalid_request", result.error
    assert_nil result.token_response
    assert_equal refresh_digest, @grant.reload.refresh_token_digest
    assert_predicate @grant.dpop_jkt, :present?
  end

  test "refreshes an operator RP session without changing auth_time" do
    root = OperatorToken.includes(:device_session).find(ActiveRecord::FixtureSet.identify(:one))
    root.update!(authentication_context: "normal")
    client = OidcClientRegistry.find!("core-org-jp")
    authentication_event_at = Time.utc(2026, 1, 2, 3, 4, 5)
    grant = OpOrgGrant.create!(
      authentication_epoch: root.authentication_epoch, operator_token_id: root.id,
      device_session_id: root.device_session_id, oidc_client_id: client.client_id,
      oidc_scope: "openid", oidc_jti: SecureRandom.uuid, oidc_nonce: "existing-nonce", oidc_acr: "aal1",
      oidc_amr: '["pwd"]', oidc_auth_time: authentication_event_at, refresh_token_expires_at: 1.hour.from_now,
    )
    refresh_token = grant.issue_refresh_token!
    assertion = OidcClientRegistry::AssertionAuthenticationResult.new(
      authenticated: true, client: client, step_up_claims_state: :none, step_up_expectation: nil,
    )
    result =
      OidcClientRegistry.stub(:verify_client_assertion, assertion) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "refresh_token", refresh_token: refresh_token, client_id: client.client_id,
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE, client_assertion: "verified-assertion",
          token_endpoint_uri: OidcIssuer.token_endpoint("operator"), expected_resource_type: "operator",
        )
      end

    assert_predicate result, :success?
    payload = JWT.decode(result.token_response.fetch(:id_token), nil, false).first

    assert_equal authentication_event_at.to_i, payload.fetch("auth_time")
  end

  test "refresh rotation preserves RP token linkage" do
    connection = ClientOidcConnection.create!(
      user_id: @root.user_id, client_id: @client.client_id, scope: "openid profile", last_used_at: 5.minutes.ago,
    )
    previous_last_used_at = connection.last_used_at
    refresh_token = @grant.issue_refresh_token!
    result = OidcRefreshTokenIssuer.call(refresh_token: refresh_token, resource_type: "client")

    assert_predicate result, :success?
    replacement = result.token

    assert_equal @root.id, replacement.client_token_id
    assert_equal @client.client_id, replacement.oidc_client_id
    assert_equal "openid profile", replacement.oidc_scope
    assert_operator connection.reload.last_used_at, :>, previous_last_used_at
  end

  test "refresh issues signed OIDC tokens with issuer public subject and split audiences" do
    refresh_token = @grant.issue_refresh_token!
    result =
      OidcClientRegistry.stub(:verify_client_assertion, @assertion) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "refresh_token", refresh_token: refresh_token, client_id: @client.client_id,
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE, client_assertion: "verified-assertion",
          token_endpoint_uri: OidcIssuer.token_endpoint("client"), expected_resource_type: "client",
        )
      end

    assert_predicate result, :success?
    id_claims, id_header = decode_op_id_token_for_test(result.token_response.fetch(:id_token), resource_type: "client")
    access_claims = AuthenticationTokenService.decode(
      result.token_response.fetch(:access_token), host: OidcIssuer.host_for_client(@client), resource_type: "client",
                                                  issuer: OidcIssuer.for_client(@client), audiences: [@client.aud],
                                                  jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_client(@client),
    )
    subject = "cli_#{@root.device_session.principal_public_id}"

    assert_equal "id-token+jwt", id_header.fetch("typ")
    assert_equal OidcIssuer.for_client(@client), id_claims.fetch("iss")
    assert_equal subject, id_claims.fetch("sub")
    assert_equal [@client.client_id], id_claims.fetch("aud")
    assert_equal @grant.oidc_nonce, id_claims.fetch("nonce")
    assert_equal OidcIssuer.for_client(@client), access_claims.fetch("iss")
    assert_equal subject, access_claims.fetch("sub")
    assert_equal [@client.aud], Array(access_claims.fetch("aud"))
    assert_equal @client.client_id, access_claims.fetch("client_id")
    assert_equal @root.public_id, access_claims.fetch("umx_base_sid")
    assert_equal "openid profile", access_claims.fetch("scope")
    assert_predicate access_claims.fetch("auth_time"), :present?
    issuer_kids =
      JitSecurityJwtRegistry.jwks_for(
        OidcIssuer.jwt_issuer_id_for_resource_type("client"),
      ).fetch(:keys).map { |key| key.fetch("kid") }
    access_header = JitSecurityJwtKeyring.parse_header(result.token_response.fetch(:access_token))

    assert_includes issuer_kids, access_header.fetch("kid")
    assert_includes issuer_kids, id_header.fetch("kid")
  end

  test "explicit public client fails without client_id" do
    result = OidcTokenExchangeCoordinator.call(
      grant_type: "authorization_code", code: "unconsumed-code", client_id: nil, expected_resource_type: "client",
    )

    assert_not result.success?
    assert_equal "invalid_client", result.error
  end

  test "retired native Palm clients cannot exchange or consume their old authorization codes" do
    store = Valkey::AuthState::AuthorizationCodeStore.new
    %w(app-ios-rp app-android-rp).each do |client_id|
      redirect_uri = "https://palm-jp.umaxica.app/oidc/callback"
      code = store.issue!(
        client_id: client_id, redirect_uri: redirect_uri, subject: "cli_#{@root.device_session.principal_public_id}",
        base_session_ref: @root.public_id, code_challenge: "a" * 43, code_challenge_method: "S256",
        resource_type: "client",
      )
      result = OidcTokenExchangeCoordinator.call(
        grant_type: "authorization_code", code: code, redirect_uri: redirect_uri, client_id: client_id,
        code_verifier: "a" * 43, expected_resource_type: "client",
      )

      assert_not result.success?, client_id
      assert_equal "invalid_client", result.error, client_id
      assert_equal "issued", store.read(code).fetch("state"), client_id
    end
  end

  test "refresh rejects DPoP proofs bound to another method or endpoint without consuming the grant" do
    private_key = OpenSSL::PKey::EC.generate("prime256v1")
    jwk = JWT::JWK.new(private_key).export
    @grant.update!(dpop_jkt: JitSecurityJwtThumbprintCalculator.calculate(jwk.stringify_keys))
    refresh_token = @grant.issue_refresh_token!
    original_digest = @grant.refresh_token_digest
    endpoint = OidcIssuer.token_endpoint("client")
    [["GET", endpoint], ["POST", "https://other.example/oauth/token"]].each do |method, uri|
      proof = JWT.encode(
        { "htm" => method, "htu" => uri, "iat" => Time.current.to_i, "jti" => SecureRandom.uuid },
        private_key, "ES256", { "typ" => "dpop+jwt", "jwk" => jwk },
      )
      result =
        OidcClientRegistry.stub(:verify_client_assertion, @assertion) do
          OidcTokenExchangeCoordinator.call(
            grant_type: "refresh_token", refresh_token: refresh_token, client_id: @client.client_id,
            client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE, client_assertion: "verified-assertion",
            dpop_proof: proof, token_endpoint_uri: endpoint, request_method: "POST", expected_resource_type: "client",
          )
        end

      assert_not result.success?
      assert_equal "invalid_request", result.error
      assert_equal original_digest, @grant.reload.refresh_token_digest
    end
  end

  test "fails invalid_client for blank configured confidential client secret" do
    client = Struct.new(:registered_token_endpoint_auth_method, :client_secret).new("client_secret_post", "")
    result =
      OidcClientRegistry.stub(:find, client) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "authorization_code", code: "unconsumed-code", client_id: "blank-secret-client",
          client_secret: "", expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "invalid_client", result.error
  end

  test "refresh grant fails closed when the RP session has no authentication event" do
    @grant.update!(oidc_auth_time: nil)
    refresh_token = @grant.issue_refresh_token!
    result =
      OidcClientRegistry.stub(:verify_client_assertion, @assertion) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "refresh_token", refresh_token: refresh_token, client_id: @client.client_id,
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE, client_assertion: "verified-assertion",
          token_endpoint_uri: OidcIssuer.token_endpoint("client"), expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "invalid_grant", result.error
    assert @grant.reload.refresh_token_digest_matches?(ClientToken.parse_refresh_token(refresh_token).last)
  end

  test "refresh grant rejects a missing refresh token before resolving storage" do
    result =
      OidcClientRegistry.stub(:verify_client_assertion, @assertion) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "refresh_token", client_id: @client.client_id,
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE, client_assertion: "verified-assertion",
          token_endpoint_uri: OidcIssuer.token_endpoint("client"), expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "invalid_grant", result.error
  end

  test "refresh grant rejects an unknown refresh token" do
    result =
      OidcClientRegistry.stub(:verify_client_assertion, @assertion) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "refresh_token", refresh_token: "not-a-refresh-token", client_id: @client.client_id,
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE, client_assertion: "verified-assertion",
          token_endpoint_uri: OidcIssuer.token_endpoint("client"), expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "invalid_grant", result.error
  end

  test "refresh grant rejects a scope that no longer contains openid" do
    @grant.update!(oidc_scope: "profile")
    refresh_token = @grant.issue_refresh_token!
    result =
      OidcClientRegistry.stub(:verify_client_assertion, @assertion) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "refresh_token", refresh_token: refresh_token, client_id: @client.client_id,
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE, client_assertion: "verified-assertion",
          token_endpoint_uri: OidcIssuer.token_endpoint("client"), expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "invalid_grant", result.error
    assert_predicate @grant.reload.refresh_token_digest, :present?
  end

  test "refresh grant rejects an inactive root session" do
    refresh_token = @grant.issue_refresh_token!
    @root.update!(discard_at: Time.current)
    result =
      OidcClientRegistry.stub(:verify_client_assertion, @assertion) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "refresh_token", refresh_token: refresh_token, client_id: @client.client_id,
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE, client_assertion: "verified-assertion",
          token_endpoint_uri: OidcIssuer.token_endpoint("client"), expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "invalid_grant", result.error
  end

  test "D-25: an unknown verifier for an existing grant and a garbage token revoke nothing" do
    current = @grant.issue_refresh_token!
    public_id, = ClientToken.parse_refresh_token(current)
    forged = ClientToken.build_refresh_token(public_id, SecureRandom.urlsafe_base64(32))
    sibling = OpAppGrant.create!(
      authentication_epoch: @root.authentication_epoch, client_token_id: @root.id,
      device_session_id: @root.device_session_id, oidc_client_id: "warp-app-jp",
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: "other-browser",
      refresh_token_expires_at: 1.hour.from_now,
    )
    sibling_refresh = sibling.issue_refresh_token!
    unknown_id = PublicId.generate

    assert_not OpAppGrant.exists?(public_id: unknown_id)
    unknown = ClientToken.build_refresh_token(unknown_id, SecureRandom.urlsafe_base64(32))
    OidcClientRegistry.stub(:verify_client_assertion, @assertion) do
      [forged, "not-a-refresh-token"].each do |invalid|
        rejected = OidcTokenExchangeCoordinator.call(
          grant_type: "refresh_token", refresh_token: invalid, client_id: @client.client_id,
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE, client_assertion: "verified-assertion",
          token_endpoint_uri: OidcIssuer.token_endpoint("client"), expected_resource_type: "client",
        )

        assert_equal "invalid_grant", rejected.error
      end
      assert_not_predicate OidcRefreshTokenIssuer.call(refresh_token: unknown, resource_type: "client"), :success?
      assert_nil @grant.reload.revoked_at
      result = OidcTokenExchangeCoordinator.call(
        grant_type: "refresh_token", refresh_token: current, client_id: @client.client_id,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE, client_assertion: "verified-assertion",
        token_endpoint_uri: OidcIssuer.token_endpoint("client"), expected_resource_type: "client",
      )

      assert_predicate result, :success?
      assert_nil sibling.reload.revoked_at
      assert_predicate OidcRefreshTokenIssuer.call(
        refresh_token: sibling_refresh, resource_type: "client", client_id: "warp-app-jp",
      ), :success?
    end
  end

  test "refresh grant rejects a different registered client without rotating the usage" do
    refresh_token = @grant.issue_refresh_token!
    other_client = OidcClientRegistry.find!("warp-app-jp")
    other_assertion = OidcClientRegistry::AssertionAuthenticationResult.new(
      authenticated: true, client: other_client, step_up_claims_state: :none, step_up_expectation: nil,
    )
    result =
      OidcClientRegistry.stub(:verify_client_assertion, other_assertion) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "refresh_token", refresh_token: refresh_token, client_id: other_client.client_id,
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE, client_assertion: "verified-assertion",
          token_endpoint_uri: OidcIssuer.token_endpoint("client"), expected_resource_type: "client",
        )
      end

    assert_not result.success?
    assert_equal "invalid_grant", result.error
    follow_up =
      OidcClientRegistry.stub(:verify_client_assertion, @assertion) do
        OidcTokenExchangeCoordinator.call(
          grant_type: "refresh_token", refresh_token: refresh_token, client_id: @client.client_id,
          client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE, client_assertion: "verified-assertion",
          token_endpoint_uri: OidcIssuer.token_endpoint("client"), expected_resource_type: "client",
        )
      end

    assert_predicate follow_up, :success?
  end

  test "D-25: every refresh use rotates and the consumed predecessor is never accepted again" do
    first = @grant.issue_refresh_token!
    OidcClientRegistry.stub(:verify_client_assertion, @assertion) do
      second = OidcTokenExchangeCoordinator.call(
        grant_type: "refresh_token", refresh_token: first, client_id: @client.client_id,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE, client_assertion: "verified-assertion",
        token_endpoint_uri: OidcIssuer.token_endpoint("client"), expected_resource_type: "client",
      )
      third = OidcTokenExchangeCoordinator.call(
        grant_type: "refresh_token", refresh_token: second.token_response.fetch(:refresh_token),
        client_id: @client.client_id, client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE,
        client_assertion: "verified-assertion", token_endpoint_uri: OidcIssuer.token_endpoint("client"),
        expected_resource_type: "client",
      )

      assert_predicate second, :success?
      assert_predicate third, :success?
      assert_equal 3, [first, second.token_response.fetch(:refresh_token), third.token_response.fetch(:refresh_token)]
        .uniq.size
    end
  end

  test "D-25: reuse of a consumed refresh token is invalid_grant and revokes only that grant's family" do
    predecessor = @grant.issue_refresh_token!
    sibling = OpAppGrant.create!(
      authentication_epoch: @root.authentication_epoch, client_token_id: @root.id,
      device_session_id: @root.device_session_id, oidc_client_id: "warp-app-jp",
      oidc_scope: "openid profile", oidc_jti: SecureRandom.uuid, oidc_nonce: "other-browser",
      refresh_token_expires_at: 1.hour.from_now,
    )
    sibling_refresh = sibling.issue_refresh_token!

    OidcClientRegistry.stub(:verify_client_assertion, @assertion) do
      first = OidcTokenExchangeCoordinator.call(
        grant_type: "refresh_token", refresh_token: predecessor, client_id: @client.client_id,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE, client_assertion: "verified-assertion",
        token_endpoint_uri: OidcIssuer.token_endpoint("client"), expected_resource_type: "client",
      )

      assert_predicate first, :success?
      successor = first.token_response.fetch(:refresh_token)
      reused = OidcTokenExchangeCoordinator.call(
        grant_type: "refresh_token", refresh_token: predecessor, client_id: @client.client_id,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE, client_assertion: "verified-assertion",
        token_endpoint_uri: OidcIssuer.token_endpoint("client"), expected_resource_type: "client",
      )
      follow_up = OidcTokenExchangeCoordinator.call(
        grant_type: "refresh_token", refresh_token: successor, client_id: @client.client_id,
        client_assertion_type: OidcClientAssertionJwt::ASSERTION_TYPE, client_assertion: "verified-assertion",
        token_endpoint_uri: OidcIssuer.token_endpoint("client"), expected_resource_type: "client",
      )

      assert_equal "invalid_grant", reused.error
      assert_predicate @grant.reload.revoked_at, :present?
      assert_equal "invalid_grant", follow_up.error, "the whole family is revoked, successor included"
      assert_predicate @root.reload, :active_status?, "the OP Root Session stays intact"
      assert_nil sibling.reload.revoked_at
      assert_predicate OidcRefreshTokenIssuer.call(
        refresh_token: sibling_refresh, resource_type: "client", client_id: "warp-app-jp",
      ), :success?
    end
  end
end
