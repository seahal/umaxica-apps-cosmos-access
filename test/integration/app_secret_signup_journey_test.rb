# frozen_string_literal: true

require "test_helper"

class AppSecretSignupJourneyTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "telephone and secret sign-up entry points refuse without changing existing session authority" do
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

    [[:get, "/sign/up/telephone/new"], [:post, "/sign/up/telephone"],
     [:get, "/sign/up/check/telephone/secret"], [:post, "/sign/up/check/telephone/secret"],
     [:patch, "/sign/up/check/telephone/secret"], [:delete, "/sign/up/check/telephone/secret"],].each do |verb, path|
      case verb
      when :get then get(path)
      when :post then post(path)
      when :patch then patch(path)
      when :delete then delete(path)
      end

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
