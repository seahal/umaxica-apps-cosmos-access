# frozen_string_literal: true

require "test_helper"

class AuthenticationLogoutResolverRoundTripTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(client_tokens client_device_sessions)

  test "access token stops resolving an OP root after current-session logout" do
    root = ClientToken.includes(:device_session).find(ActiveRecord::FixtureSet.identify(:one))
    host = OidcIssuer.host_for_resource_type("client")
    payload = AuthorizationTokenClaims.build(
      resource: nil, subject: root.subject_public_id.to_s, resource_type: "client", issued_at: Time.current,
      access_token_ttl: 60.seconds, session_public_id: root.device_session.public_id,
      oidc_jti: root.oidc_jti, authentication_context: AuthenticationContextValue::NORMAL_KEY,
    )
    access_token = JitSecurityJwtKeyring.encode(
      payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
               issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"),
    )
    resolve = -> { OpBrowserSessionResolver.call(access_token:, request_host: host, resource_type: "client") }

    assert_equal root.id, resolve.call.root&.id
    AuthenticationLogoutCurrentSession.call(
      cause: "browser_logout", token_class: ClientToken,
      session_public_id: root.device_session.public_id, reason: "user_logout",
    )

    assert_nil resolve.call.root
    assert_predicate root.reload, :revoked?
    assert_predicate root.device_session.reload, :revoked?
  end

  test "current-session logout revokes a fallback device with no current refresh token" do
    root = ClientToken.includes(:device_session).find(ActiveRecord::FixtureSet.identify(:one))
    device = root.device_session
    device.update!(current_refresh_token_id: nil)

    assert_nil device.reload.current_refresh_token_id
    AuthenticationLogoutCurrentSession.call(
      cause: "browser_logout", token_class: ClientToken, session_public_id: root.public_id, reason: "user_logout",
    )

    assert_predicate device.reload, :revoked?
    assert_predicate root.reload, :revoked?
  end
end
