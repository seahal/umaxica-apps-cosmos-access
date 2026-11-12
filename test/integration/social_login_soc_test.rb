# frozen_string_literal: true

require "test_helper"

class SocialLoginSocTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "provider entry and callbacks fail closed without changing existing OP authority" do
    device = ClientDeviceSession.create!(user_id: 9_700_001, principal_public_id: "historical-subject")
    root = ClientToken.create!(user_id: 9_700_001, device_session: device, authentication_epoch: 0)
    root_before = root.reload.attributes
    device_before = device.reload.attributes
    counts = [ClientToken.count, ClientDeviceSession.count, OpAppGrant.count]
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    https!
    payload = AuthorizationTokenClaims.build(
      resource: nil, subject: root.user_id.to_s, resource_type: "client", issued_at: Time.current,
      access_token_ttl: 60.seconds, session_public_id: device.public_id, oidc_jti: root.oidc_jti,
      authentication_context: AuthenticationContextValue::NORMAL_KEY,
    )
    cookies[AuthenticationCookieName.access] = JitSecurityJwtKeyring.encode(
      payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
               issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"),
    )

    %w(google apple).each do |provider|
      ["/social/#{provider}", "/social/#{provider}/session", "/social/#{provider}/registration"].each do |path|
        post path, params: { state: "untrusted", code: "untrusted" }

        assert_response :service_unavailable
        assert_equal "Service unavailable", response.body
        assert_nil response.headers["Location"]
        assert_includes response.headers.fetch("Cache-Control"), "no-store"
        assert_not response.headers["Set-Cookie"].to_s.match?(/(?:__Host-)?auth_sid=/)
        assert_equal counts, [ClientToken.count, ClientDeviceSession.count, OpAppGrant.count]
        assert_equal root_before, root.reload.attributes
        assert_equal device_before, device.reload.attributes
      end
      get "/social/#{provider}/callback", params: { state: "untrusted", code: "untrusted" }

      assert_response :service_unavailable
      assert_equal "Service unavailable", response.body
      assert_nil response.headers["Location"]
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
      assert_not response.headers["Set-Cookie"].to_s.match?(/(?:__Host-)?auth_sid=/)
      assert_equal counts, [ClientToken.count, ClientDeviceSession.count, OpAppGrant.count]
      assert_equal root_before, root.reload.attributes
      assert_equal device_before, device.reload.attributes
    end
  end
end
