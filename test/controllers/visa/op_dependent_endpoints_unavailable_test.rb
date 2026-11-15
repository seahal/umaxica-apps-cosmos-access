# typed: false
# frozen_string_literal: true

require "test_helper"

class VisaOpDependentEndpointsUnavailableTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = %w(client_tokens operator_tokens client_device_sessions operator_device_sessions)

  test "UserInfo authenticates real OP credentials before refusing unavailable Governance profile data" do
    [["client", ClientToken, ClientDeviceSession, "core-app-jp"],
     ["operator", OperatorToken, OperatorDeviceSession, "core-org-jp"],].each do |type, roots, devices, client_id|
      root = roots.find(ActiveRecord::FixtureSet.identify(:one))
      root.update!(authentication_context: "normal") if type == "operator"
      device = devices.find(root.device_session_id)
      client = OidcClientRegistry.find!(client_id)
      host = OidcIssuer.host_for_resource_type(type)
      host!(host)
      https!
      token = AuthenticationTokenService.encode(
        nil, host: host, resource_type: type, session_public_id: root.public_id,
             base_session_public_id: root.public_id, oidc_sid: PublicId.generate, oidc_jti: SecureRandom.uuid,
             scopes: %w(openid), issuer: OidcIssuer.for_resource_type(type), audiences: [client.aud],
             subject: "#{OidcSubject.prefix_for(type)}_#{device.subject_public_id}",
             jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type), client_id: client_id,
             expires_at: 5.minutes.from_now, authentication_context: root.strict_authentication_context_value.to_s,
      )
      get "/oauth/userinfo", headers: { "Authorization" => "Bearer #{token}" }

      assert_response :service_unavailable
      assert_equal "Service unavailable", response.body
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
      assert_equal "no-cache", response.headers["Pragma"]
      assert_nil response.headers["Set-Cookie"]
      post "/oauth/userinfo", headers: { "Authorization" => "Bearer #{token}" }

      assert_response :service_unavailable
      assert_equal "Service unavailable", response.body
      get "/oauth/userinfo", headers: { "Authorization" => "Bearer invalid" }

      assert_response :unauthorized
      assert_equal 'Bearer error="invalid_token"', response.headers["WWW-Authenticate"]
    end
  end

  test "UserInfo retains missing malformed alternate transport and scope errors" do
    [["client", ClientToken, ClientDeviceSession, "core-app-jp"],
     ["operator", OperatorToken, OperatorDeviceSession, "core-org-jp"],].each do |type, roots, devices, client_id|
      root = roots.find(ActiveRecord::FixtureSet.identify(:one))
      root.update!(authentication_context: "normal") if type == "operator"
      device = devices.find(root.device_session_id)
      client = OidcClientRegistry.find!(client_id)
      host = OidcIssuer.host_for_resource_type(type)
      host!(host)
      https!
      get "/oauth/userinfo"

      assert_response :unauthorized
      assert_equal "Bearer", response.headers["WWW-Authenticate"]
      get "/oauth/userinfo", params: { access_token: "query-token" }

      assert_response :bad_request
      get "/oauth/userinfo", headers: { "Authorization" => "Basic invalid" }

      assert_response :bad_request
      token = AuthenticationTokenService.encode(
        nil, host: host, resource_type: type, session_public_id: root.public_id,
             base_session_public_id: root.public_id, oidc_sid: PublicId.generate, oidc_jti: SecureRandom.uuid,
             scopes: %w(profile), issuer: OidcIssuer.for_resource_type(type), audiences: [client.aud],
             subject: "#{OidcSubject.prefix_for(type)}_#{device.subject_public_id}",
             jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type), client_id: client_id,
             expires_at: 5.minutes.from_now, authentication_context: root.strict_authentication_context_value.to_s,
      )
      get "/oauth/userinfo", headers: { "Authorization" => "Bearer #{token}" }

      assert_response :forbidden
      assert_equal 'Bearer error="insufficient_scope", scope="openid"', response.headers["WWW-Authenticate"]
    end
  end

  test "sensitive APIs verify client assertion and OP grant before refusing every new workflow" do
    [["client", ClientToken, ClientDeviceSession, OpAppGrant, :client_token_id, "base-app-ww",
      ClientVisaSensitiveAdmission,],
     ["operator", OperatorToken, OperatorDeviceSession, OpOrgGrant, :operator_token_id, "base-org-ww",
      OperatorVisaSensitiveAdmission,],].each do |type, roots, devices, grants, root_key, client_id, admissions|
      root = roots.find(ActiveRecord::FixtureSet.identify(:one))
      root.update!(authentication_context: "normal") if type == "operator"
      device = devices.find(root.device_session_id)
      client = OidcClientRegistry.find!(client_id)
      grant = grants.create!(
        root_key => root.id, :device_session_id => device.id, :authentication_epoch => root.authentication_epoch,
        :oidc_client_id => client_id, :oidc_scope => "openid", :oidc_jti => SecureRandom.uuid,
        :refresh_token_expires_at => 1.hour.from_now,
      )
      host = OidcIssuer.host_for_resource_type(type)
      host!(host)
      https!
      token = AuthenticationTokenService.encode(
        nil, host: host, resource_type: type, session_public_id: root.public_id,
             base_session_public_id: root.public_id, oidc_sid: grant.public_id, oidc_jti: grant.oidc_jti,
             scopes: %w(openid), issuer: OidcIssuer.for_resource_type(type), audiences: [client.aud],
             subject: "#{OidcSubject.prefix_for(type)}_#{device.subject_public_id}",
             jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type(type), client_id: client_id,
             expires_at: 5.minutes.from_now, authentication_context: root.strict_authentication_context_value.to_s,
      )
      requests = [
        ["/api/v0/sensitive_admissions", {
          rp_session_ref: PublicId.generate,
          rp_session_expires_at: 10.minutes.from_now.iso8601,
          browser_binding_digest: "a" * 64,
          purpose: "passkey_registration",
          provider: "none",
          response_type: "code",
          client_id: client_id,
          redirect_uri: client.redirect_uris.first,
          scope: "openid",
          state: SecureRandom.hex(16),
          nonce: SecureRandom.hex(16),
          code_challenge: "A" * 43,
          code_challenge_method: "S256",
          claims: "{}",
        },],
        ["/api/v0/sensitive_admission_confirmation", {
          admission_ref: PublicId.generate, rp_session_ref: PublicId.generate, browser_binding_digest: "a" * 64,
        },],
      ]
      before = admissions.count
      requests.each do |path, body|
        assertion = OidcClientAssertionJwt.issue(client_id: client_id, token_url: "https://#{host}#{path}")
        post path, params: body, headers: {
          "Authorization" => "Bearer #{token}", "X-Client-Assertion" => assertion,
        }

        assert_response :service_unavailable
        assert_equal "Service unavailable", response.body
        assert_equal before, admissions.count
      end
      path = "/api/v0/sensitive_admission_session"
      assertion = OidcClientAssertionJwt.issue(client_id: client_id, token_url: "https://#{host}#{path}")
      patch path, params: { rp_session_ref: PublicId.generate }, headers: {
        "Authorization" => "Bearer #{token}", "X-Client-Assertion" => assertion,
      }

      assert_response :service_unavailable
      assert_equal "Service unavailable", response.body
      assert_equal before, admissions.count
      %w(/api/v0/sensitive_admissions /api/v0/sensitive_admission_confirmation).each do |missing_path|
        assertion = OidcClientAssertionJwt.issue(client_id: client_id, token_url: "https://#{host}#{missing_path}")
        post missing_path, params: {}, headers: {
          "Authorization" => "Bearer #{token}", "X-Client-Assertion" => assertion,
        }

        assert_response :bad_request
        assert_equal "invalid_request", response.parsed_body.fetch("error")
        assert_equal before, admissions.count
      end
      post "/api/v0/sensitive_admissions", params: {}

      assert_response :unauthorized
      assert_equal "invalid_client", response.parsed_body.fetch("error")
      OpAuthorityStopCommitter.stop_grant(
        grant: grant, cause: "token_revocation", principal_public_id: device.subject_public_id,
        authority_evidence_ref: "sensitive-api-contract:#{grant.public_id}",
      )
      get "/oauth/userinfo", headers: { "Authorization" => "Bearer #{token}" }

      assert_response :service_unavailable
      assertion = OidcClientAssertionJwt.issue(client_id: client_id, token_url: "https://#{host}#{path}")
      patch path, params: { rp_session_ref: PublicId.generate }, headers: {
        "Authorization" => "Bearer #{token}", "X-Client-Assertion" => assertion,
      }

      assert_response :unauthorized
      assert_equal "invalid_token", response.parsed_body.fetch("error")
      assert_equal before, admissions.count
    end
  end
end
