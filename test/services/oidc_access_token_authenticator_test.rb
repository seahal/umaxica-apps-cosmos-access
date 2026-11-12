# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcAccessTokenAuthenticatorTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(client_tokens operator_tokens client_device_sessions operator_device_sessions)

  test "normal Access JWT authentication keeps its independent RP grant and refresh idle lifecycle" do
    [["client", ClientToken, ClientDeviceSession, OpAppGrant, "core-app-jp"],
     ["operator", OperatorToken, OperatorDeviceSession, OpOrgGrant,
      "core-org-jp",],].each do |type, roots, devices, grants, client_id|
      root = roots.find(ActiveRecord::FixtureSet.identify(:one))
      device = devices.find(root.device_session_id)
      client = OidcClientRegistry.find!(client_id)
      root.update!(authentication_context: "normal") if type == "operator"
      roots.where(id: root.id).update_all(last_used_at: 2.years.ago)
      token = AuthenticationTokenService.encode(
        nil, host: OidcIssuer.host_for_resource_type(type), resource_type: type,
             session_public_id: root.public_id, base_session_public_id: root.public_id,
             oidc_sid: PublicId.generate, oidc_jti: SecureRandom.uuid, expires_at: 5.minutes.from_now,
             scopes: %w(openid), issuer: OidcIssuer.for_resource_type(type), audiences: [client.aud],
             subject: "#{OidcSubject.prefix_for(type)}_#{device.principal_public_id}",
             jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type), client_id: client.client_id,
             authentication_context: root.strict_authentication_context_value.to_s,
      )
      connections = []
      observer = ->(event) { connections << event.payload.fetch(:connection).pool.db_config.name }
      result = nil
      grants.stub(:find_by, ->(**) { flunk("normal Access JWT authentication must not query RP Sessions") }) do
        ActiveSupport::Notifications.subscribed(observer, "sql.active_record") do
          roots.connection_class_for_self.connected_to(role: :reading) do
            result = OidcAccessTokenAuthenticator.call(
              access_token: token, resource_type: type, host: OidcIssuer.host_for_resource_type(type),
            )
          end
        end
      end

      assert_predicate result, :success?
      assert_equal root, result.token
      assert_equal device, result.device
      assert_equal device.principal_public_id, result.principal_public_id
      assert_not_respond_to result, :resource
      assert_empty connections.grep(/zenith|replica/)
    end
  end

  test "signed JWTs refuse broken issuer audience client subject session and context bindings" do
    [["client", ClientToken, ClientDeviceSession, "core-app-jp", "core-org-jp"],
     ["operator", OperatorToken, OperatorDeviceSession, "core-org-jp",
      "core-app-jp",],].each do |type, roots, devices, client_id, other_client|
      root = roots.find(ActiveRecord::FixtureSet.identify(:one))
      device = devices.find(root.device_session_id)
      root.update!(authentication_context: "normal") if type == "operator"
      client = OidcClientRegistry.find!(client_id)
      host = OidcIssuer.host_for_resource_type(type)
      claims = {
        "iss" => OidcIssuer.for_resource_type(type),
        "aud" => [client.aud],
        "iat" => Time.current.to_i,
        "nbf" => Time.current.to_i,
        "exp" => 5.minutes.from_now.to_i,
        "jti" => SecureRandom.uuid,
        "sub" => "#{OidcSubject.prefix_for(type)}_#{device.principal_public_id}",
        "client_id" => client_id,
        "scope" => "openid",
        "acr" => "aal1",
        "sid" => PublicId.generate,
        "umx_base_sid" => root.public_id,
        AuthenticationContextValue::CLAIM => root.strict_authentication_context_value.to_s,
      }
      [
        { "iss" => "https://foreign.example" }, { "aud" => ["foreign-audience"] },
        { "client_id" => other_client }, { "client_id" => "unregistered" },
        { "sub" => "#{OidcSubject.prefix_for(type)}_another-principal" },
        { "sub" => "wrong-prefix_subject" }, { "umx_base_sid" => PublicId.generate },
        { "umx_base_sid" => "" }, { "exp" => 1.minute.ago.to_i },
        { AuthenticationContextValue::CLAIM => nil }, { AuthenticationContextValue::CLAIM => "" },
        { AuthenticationContextValue::CLAIM => "unknown" }, { AuthenticationContextValue::CLAIM => "standby" },
      ].each do |change|
        token = JitSecurityJwtKeyring.encode(
          claims.merge(change), typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
                                issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
        )
        result = OidcAccessTokenAuthenticator.call(access_token: token, resource_type: type, host: host)

        assert_not_predicate result, :success?, change.keys.inspect
        assert_equal "invalid_token", result.error
      end
      token = JitSecurityJwtKeyring.encode(
        claims.merge("scope" => "profile"), typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
                                            issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type),
      )

      assert_equal "insufficient_scope", OidcAccessTokenAuthenticator.call(
        access_token: token, resource_type: type,
        host: host,
      ).error
      [nil, "", "not-a-jwt"].each do |missing|
        assert_equal "invalid_token", OidcAccessTokenAuthenticator.call(
          access_token: missing, resource_type: type,
          host: host,
        ).error
      end
    end
  end

  test "root status rotation and absolute expiry retain their rejection boundaries" do
    [["client", ClientToken, ClientDeviceSession, ClientTokenStatus, :user_token_status_id, "core-app-jp"],
     ["operator", OperatorToken, OperatorDeviceSession, OperatorTokenStatus, :staff_token_status_id,
      "core-org-jp",],].each do |type, roots, devices, statuses, status_key, client_id|
      root = roots.find(ActiveRecord::FixtureSet.identify(:one))
      device = devices.find(root.device_session_id)
      root.update!(authentication_context: "normal") if type == "operator"
      client = OidcClientRegistry.find!(client_id)
      token = AuthenticationTokenService.encode(
        nil, host: OidcIssuer.host_for_resource_type(type), resource_type: type,
             session_public_id: root.public_id, base_session_public_id: root.public_id,
             oidc_sid: PublicId.generate, oidc_jti: SecureRandom.uuid, expires_at: 5.minutes.from_now,
             scopes: %w(openid), issuer: OidcIssuer.for_resource_type(type), audiences: [client.aud],
             subject: "#{OidcSubject.prefix_for(type)}_#{device.principal_public_id}",
             jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type), client_id: client_id,
             authentication_context: root.strict_authentication_context_value.to_s,
      )
      [statuses::RESTRICTED, statuses::REVOKED, statuses::EXPIRED].each do |status|
        roots.where(id: root.id).update_all(status_key => status)

        assert_equal "invalid_token", OidcAccessTokenAuthenticator.call(
          access_token: token, resource_type: type, host: OidcIssuer.host_for_resource_type(type),
        ).error
      end
      roots.where(id: root.id).update_all(status_key => statuses::ACTIVE, :rotated_at => Time.current)

      assert_equal "invalid_token", OidcAccessTokenAuthenticator.call(
        access_token: token, resource_type: type, host: OidcIssuer.host_for_resource_type(type),
      ).error
      roots.where(id: root.id).update_all(rotated_at: nil, created_at: 1.hour.ago)
      now = Time.current.change(usec: 0)
      travel_to(now) do
        microsecond = Rational(1, 1_000_000)
        [-microsecond, 0, microsecond].each do |offset|
          roots.where(id: root.id).update_all(discard_at: now + offset.seconds)
          result = OidcAccessTokenAuthenticator.call(
            access_token: token, resource_type: type, host: OidcIssuer.host_for_resource_type(type),
          )

          assert_equal offset.positive?, result.success?, "expiry offset #{offset}"
        end
      end
    end
  end

  test "DPoP-bound and unbound token scheme boundaries remain enforced" do
    root = ClientToken.find(ActiveRecord::FixtureSet.identify(:one))
    device = ClientDeviceSession.find(root.device_session_id)
    client = OidcClientRegistry.find!("core-app-jp")
    host = OidcIssuer.host_for_resource_type("client")
    [nil, "bound-thumbprint"].each do |thumbprint|
      token = AuthenticationTokenService.encode(
        nil, host: host, resource_type: "client", session_public_id: root.public_id,
             base_session_public_id: root.public_id, oidc_sid: PublicId.generate, oidc_jti: SecureRandom.uuid,
             expires_at: 5.minutes.from_now, scopes: %w(openid), issuer: OidcIssuer.for_resource_type("client"),
             audiences: [client.aud], subject: "cli_#{device.principal_public_id}",
             jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"), client_id: client.client_id,
             authentication_context: "normal", dpop_jkt: thumbprint,
      )
      [{ authorization_scheme: "Bearer", dpop_proof: "stray-proof" },
       { authorization_scheme: "DPoP", dpop_proof: "invalid-proof" },].each do |arguments|
        result = OidcAccessTokenAuthenticator.call(
          access_token: token, resource_type: "client", host: host, **arguments,
          request_method: "GET", request_uri: "https://#{host}/oauth/userinfo",
        )

        assert_equal "invalid_token", result.error
      end
      next unless thumbprint

      assert_equal "invalid_token", OidcAccessTokenAuthenticator.call(
        access_token: token, resource_type: "client", host: host, authorization_scheme: "Bearer",
      ).error
    end
  end
end
