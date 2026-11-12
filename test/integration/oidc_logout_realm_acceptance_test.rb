# frozen_string_literal: true

require "test_helper"

class OidcLogoutRealmAcceptanceTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = %w(client_tokens operator_tokens client_device_sessions operator_device_sessions)

  test "APP logout preserves the ORG session and refuses an ORG hint at APP" do
    app = ClientToken.create!(
      authentication_epoch: 0, user_id: 1001,
      device_session: ClientDeviceSession.create!(
        user_id: 1001, principal_public_id: "logout-client",
      ),
      user_token_kind_id: ClientTokenKind::BROWSER_WEB,
    )
    org = OperatorToken.create!(
      authentication_epoch: 0, staff_id: 1002,
      device_session: OperatorDeviceSession.create!(
        staff_id: 1002, principal_public_id: "logout-operator",
      ),
      staff_token_kind_id: OperatorTokenKind::BROWSER_WEB,
    )
    grant = OpOrgGrant.create!(
      authentication_epoch: 0, operator_token_id: org.id, device_session_id: org.device_session_id,
      oidc_client_id: "core-org-jp", oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid, oidc_nonce: SecureRandom.hex(16), oidc_auth_time: 1.minute.ago,
      refresh_token_expires_at: 10.minutes.from_now,
    )
    OpOrgGrantLogoutHint.create!(
      grant:,
      id_token: OidcIdTokenIssuer.call(
        resource_type: "operator", client: OidcClientRegistry.find!(grant.oidc_client_id), nonce: grant.oidc_nonce,
        subject: "opr_#{org.principal_public_id}", sid: grant.public_id, auth_time: grant.oidc_auth_time,
      ),
    )
    host = Rails.configuration.x.boot_config.fetch(:hosts).visa_service.host
    browser = open_session
    browser.host!(host)
    browser.https!
    payload = AuthorizationTokenClaims.build(
      resource: nil, subject: app.user_id.to_s, resource_type: "client", issued_at: Time.current,
      access_token_ttl: 60.seconds, session_public_id: app.device_session.public_id,
      oidc_jti: app.oidc_jti, authentication_context: AuthenticationContextValue::NORMAL_KEY,
    )
    access = JitSecurityJwtKeyring.encode(
      payload, typ: SecurityJwtAuthAccessTokenCodec::TOKEN_TYPE,
               issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"),
    )
    browser.cookies << Rack::Test::Cookie.new(
      "#{AuthenticationCookieName.access}=#{Rack::Utils.escape(access)}", URI.parse("https://#{host}/"),
    )
    browser.get(
      "/oidc/logout",
      params: { client_id: grant.oidc_client_id,
                id_token_hint: OpOrgGrantLogoutHint.find_by!(grant_id: grant.id).id_token,
                ri: "jp", },
    )

    assert_equal 400, browser.response.status
    assert_nil browser.response.location
    assert_predicate org.reload, :currently_usable?
    assert_predicate grant.reload, :active?

    browser.post("/oidc/logout", params: { ri: "jp" })

    assert_equal 200, browser.response.status
    browser.post("/oidc/logout/confirmation?ri=jp")

    assert_equal 303, browser.response.status
    assert_predicate app.reload, :revoked?
    assert_predicate org.reload, :currently_usable?
    assert_predicate grant.reload, :active?
  end
end
