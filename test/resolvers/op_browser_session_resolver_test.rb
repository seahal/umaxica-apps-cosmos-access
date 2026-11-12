# frozen_string_literal: true

require "test_helper"

class OpBrowserSessionResolverTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(client_tokens operator_tokens client_device_sessions operator_device_sessions)

  test "signed existing browser credentials resolve real OP roots without actor models" do
    [["client", ClientToken, :user_id], ["operator", OperatorToken, :staff_id]].each do |type, model, actor_key|
      root = model.includes(:device_session).find(ActiveRecord::FixtureSet.identify(:one))
      root.update!(authentication_context: "normal") if type == "operator"
      issuer_id = OidcIssuer.jwt_issuer_id_for_resource_type(type)
      host = OidcIssuer.host_for_resource_type(type)
      payload = AuthorizationTokenClaims.build(
        resource: nil, subject: root[actor_key].to_s, resource_type: type,
        issued_at: Time.current, access_token_ttl: 60.seconds,
        session_public_id: root.device_session.public_id,
        oidc_jti: root.oidc_jti,
        authentication_context: AuthenticationContextValue::NORMAL_KEY,
      )
      credential = JitSecurityJwtKeyring.encode(
        payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE, issuer_id: issuer_id,
      )

      result = OpBrowserSessionResolver.call(access_token: credential, request_host: host, resource_type: type)

      assert_predicate result, :success?, result.failure_reason.to_s
      assert_equal root.id, result.root.id
      assert_equal payload.fetch("sub"), result.payload.fetch("sub")

      mismatched = JitSecurityJwtKeyring.encode(
        payload.merge("sub" => (root[actor_key] + 1).to_s),
        typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE, issuer_id: issuer_id,
      )
      rejected = OpBrowserSessionResolver.call(access_token: mismatched, request_host: host, resource_type: type)

      assert_not rejected.success?
      assert_nil rejected.root
      assert_equal :subject_mismatch, rejected.failure_reason
    end
  end

  test "an expired access credential can reduce authority through logout but cannot authenticate an API" do
    root = ClientToken.includes(:device_session).find(ActiveRecord::FixtureSet.identify(:one))
    payload = AuthorizationTokenClaims.build(
      resource: nil, subject: root.user_id.to_s, resource_type: "client",
      issued_at: 5.minutes.ago, access_token_ttl: 60.seconds,
      session_public_id: root.device_session.public_id,
      oidc_jti: root.oidc_jti,
      authentication_context: AuthenticationContextValue::NORMAL_KEY,
    )
    credential = JitSecurityJwtKeyring.encode(
      payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
               issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"),
    )
    normal = OpBrowserSessionResolver.call(
      access_token: credential, request_host: OidcIssuer.host_for_resource_type("client"), resource_type: "client",
    )
    logout = OpBrowserSessionResolver.call(
      access_token: credential, request_host: OidcIssuer.host_for_resource_type("client"), resource_type: "client",
      allow_expired: true,
    )

    assert_not normal.success?
    assert_predicate logout, :success?, logout.failure_reason.to_s
    assert_equal root.id, logout.root.id
    root.revoke!
    revoked = OpBrowserSessionResolver.call(
      access_token: credential, request_host: OidcIssuer.host_for_resource_type("client"), resource_type: "client",
      allow_expired: true,
    )

    assert_not revoked.success?
    assert_nil revoked.root
  end
end
