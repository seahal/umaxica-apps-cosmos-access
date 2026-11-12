# typed: false
# frozen_string_literal: true

require "test_helper"

# OidcTokenRevoker resolves the record to revoke through the surface that owns
# the registered client: an operator client must never reach a visitor usage row
# and vice versa. OidcTokenRevokerCoverageTest stubs the lookups away, so these
# tests exercise them against the real per-surface ticket databases, including
# an access token bound to an OAuth usage row rather than to a parent browser
# session row.
class OidcTokenRevokerSurfaceLookupTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(
    client_tokens client_device_sessions client_token_kinds client_token_statuses
    client_token_binding_methods client_token_dbsc_statuses operator_tokens operator_device_sessions
    operator_token_kinds operator_token_statuses operator_token_binding_methods operator_token_dbsc_statuses
  )

  test "a staff client revokes its own refresh token usage" do
    token = OperatorToken.find(ActiveRecord::FixtureSet.identify(:one))
    usage = OpOrgGrant.create!(
      authentication_epoch: 0,
      operator_token_id: token.id,
      device_session_id: token.device_session_id,
      oidc_client_id: "core-org-jp",
      refresh_token_expires_at: 1.hour.from_now,
    )
    refresh_token = usage.issue_refresh_token!

    result =
      OidcClientRegistry.stub(:authenticate, true) do
        OidcTokenRevoker.call(
          token: refresh_token, client_id: "core-org-jp", client_secret: "secret",
          token_type_hint: "refresh_token",
        )
      end

    assert_predicate result, :success?
    assert_predicate usage.reload, :revoked?
  end

  test "an access token sid that names only the parent does not revoke the parent" do
    token = ClientToken.find(ActiveRecord::FixtureSet.identify(:one))
    payload = { "sid" => token.public_id, "jti" => SecureRandom.uuid }

    result =
      OidcClientRegistry.stub(:authenticate, true) do
        AuthenticationTokenService.stub(:decode_allow_expired, payload) do
          OidcTokenRevoker.call(
            token: "opaque-access-token", client_id: "core-app-jp", client_secret: "secret",
          )
        end
      end

    assert_predicate result, :success?
    assert_predicate token.reload, :currently_usable?
  end

  test "an access token whose jti does not match the session is not revoked" do
    root = ClientToken.find(ActiveRecord::FixtureSet.identify(:one))
    grant = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token_id: root.id,
      device_session_id: root.device_session_id,
      oidc_client_id: "core-app-jp",
      oidc_jti: SecureRandom.uuid,
      oidc_scope: "openid",
      refresh_token_expires_at: 1.hour.from_now,
    )
    payload = { "sid" => grant.public_id, "jti" => SecureRandom.uuid }

    OidcClientRegistry.stub(:authenticate, true) do
      AuthenticationTokenService.stub(:decode_allow_expired, payload) do
        OidcTokenRevoker.call(
          token: "opaque-access-token", client_id: "core-app-jp", client_secret: "secret",
        )
      end
    end

    assert_not grant.reload.revoked?
  end
end
