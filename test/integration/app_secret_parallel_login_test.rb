# frozen_string_literal: true

require "test_helper"

class AppSecretParallelLoginTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "secret login requests and retries are unavailable without changing an existing session" do
    device = ClientDeviceSession.create!(user_id: 9_700_001, principal_public_id: "historical-subject")
    root = ClientToken.create!(user_id: 9_700_001, device_session: device, authentication_epoch: 0)
    before = [root.reload.attributes, device.reload.attributes]
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

    2.times do
      post "/sign/in/secret", params: { secret: "untrusted" }

      assert_response :service_unavailable
      assert_equal "Service unavailable", response.body
      assert_nil response.headers["Location"]
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
      assert_equal counts, [ClientToken.count, ClientDeviceSession.count, OpAppGrant.count]
      assert_equal before, [root.reload.attributes, device.reload.attributes]
    end
  end
end
