# typed: false
# frozen_string_literal: true

require "test_helper"

class OidcAccessJwtChildRevokeIndependenceTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(client_tokens client_device_sessions)

  test "Access JWT TTL is five minutes with thirty-second leeway" do
    assert_equal 5.minutes, SecurityTokenLifetimes::OIDC_ACCESS_JWT_TTL
    assert_equal 30, SecurityTokenLifetimes::OIDC_ACCESS_JWT_CLOCK_LEEWAY_SECONDS
    assert_equal 30, SecurityJwtRfc9068AccessTokenProfile::CLOCK_SKEW_LEEWAY_SECONDS
    assert_equal(
      SecurityJwtRfc9068AccessTokenProfile::CLOCK_SKEW_LEEWAY_SECONDS,
      AuthenticationJwtConfiguration.leeway_seconds,
    )
  end

  test "an exchanged Access JWT authenticates for userinfo without an RP Session lookup" do
    root, session = create_rp_session

    result = authenticate(access_token_for(root, session))

    assert_predicate result, :success?
    assert_equal root, result.token
    assert_equal root.device_session.principal_public_id, result.principal_public_id
    assert_not_respond_to result, :resource
  end

  test "revoking only the RP Session does not invalidate an already-issued Access JWT" do
    root, session = create_rp_session
    token = access_token_for(root, session)

    RpSessionRevoker.call(
      scope: :rp_session, record: session, cause: "token_revocation",
      authority_evidence_ref: "test",
    )

    assert_predicate authenticate(token), :success?
  end

  test "an Access JWT stops authenticating once its parent Browser Session is revoked" do
    root, session = create_rp_session
    token = access_token_for(root, session)

    RpSessionRevoker.call(
      scope: :browser_session, record: root, cause: "browser_logout",
      authority_evidence_ref: "test",
    )

    result = authenticate(token)

    assert_not result.success?
    assert_equal "invalid_token", result.error
    assert_predicate session.reload, :revoked?
  end

  test "an Access JWT is refused when its Base Session lacks a finite expiry" do
    root, session = create_rp_session
    token = access_token_for(root, session)
    root.update!(discard_at: Float::INFINITY, purge_eligible_at: Float::INFINITY)

    result = authenticate(token)

    assert_not result.success?
    assert_equal "invalid_token", result.error
  end

  test "an Access JWT carrying another RP Session jti remains stateless" do
    root, session = create_rp_session

    result = authenticate(access_token_for(root, session, jti: SecureRandom.uuid))

    assert_predicate result, :success?
  end

  test "revoked RP Session remains inactive while parent Base Browser Session stays usable" do
    root, session = create_rp_session

    RpSessionRevoker.call(
      scope: :rp_session, record: session, cause: "token_revocation",
      authority_evidence_ref: "test",
    )

    assert_predicate session.reload, :revoked?
    assert_not session.active?
    assert_predicate root.reload, :currently_usable?
  end

  private

  def rp_client
    @rp_client ||=
      OidcClientRegistry.client_ids
        .map { |client_id| OidcClientRegistry.find(client_id) }
        .find { |client| client && OidcIssuer.resource_type_for_client(client) == "client" }
  end

  def create_rp_session
    root = ClientToken.includes(:device_session).find(ActiveRecord::FixtureSet.identify(:one))
    session = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token_id: root.id,
      device_session_id: root.device_session_id,
      oidc_client_id: rp_client.client_id,
      oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid,
      refresh_token_expires_at: 1.hour.from_now,
    )
    [root, session]
  end

  def access_token_for(root, session, jti: session.oidc_jti)
    AuthenticationTokenService.encode(
      nil,
      host: OidcIssuer.host_for_resource_type("client"),
      resource_type: "client",
      session_public_id: root.public_id,
      base_session_public_id: root.public_id,
      oidc_sid: session.public_id,
      oidc_jti: jti,
      expires_at: 5.minutes.from_now,
      scopes: %w(openid),
      issuer: OidcIssuer.for_resource_type("client"),
      audiences: [rp_client.aud],
      subject: "cli_#{root.device_session.principal_public_id}",
      authentication_context: root.strict_authentication_context_value.to_s,
      jwt_issuer_id: OidcIssuer.jwt_issuer_id_for_resource_type("client"),
      client_id: rp_client.client_id,
    )
  end

  def authenticate(access_token)
    OidcAccessTokenAuthenticator.call(
      access_token: access_token,
      resource_type: "client",
      host: OidcIssuer.host_for_resource_type("client"),
    )
  end
end
