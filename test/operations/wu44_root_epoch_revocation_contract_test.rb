# frozen_string_literal: true

require "test_helper"

class Wu44RootEpochRevocationContractTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "single-device sign-out leaves another browser session for the same subject active" do
    principal_public_id = PublicId.generate
    signed_out_root, signed_out_device = create_app_root(principal_public_id)
    other_root, other_device = create_app_root(principal_public_id)

    AuthenticationLogoutCurrentSession.call(
      cause: "browser_logout",
      token: signed_out_root,
      reason: "A44-6-single-root",
    )

    assert_predicate signed_out_root.reload, :revoked?
    assert_predicate signed_out_device.reload, :revoked?
    assert_predicate other_root.reload, :currently_usable?
    assert_predicate other_device.reload, :usable?
  end

  test "OIDC token revocation leaves its browser session and another session active" do
    principal_public_id = PublicId.generate
    revoked_grant_root, _device = create_app_root(principal_public_id)
    other_root, other_device = create_app_root(principal_public_id)
    grant = OpAppGrant.create!(
      authentication_epoch: revoked_grant_root.authentication_epoch,
      client_token_id: revoked_grant_root.id,
      device_session_id: revoked_grant_root.device_session_id,
      oidc_client_id: "core-app-jp",
      oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid,
      refresh_token_expires_at: 1.hour.from_now,
    )
    refresh_token = grant.issue_refresh_token!

    result =
      OidcClientRegistry.stub(:authenticate, true) do
        OidcTokenRevoker.call(
          token: refresh_token,
          client_id: "core-app-jp",
          client_secret: "test-client-secret",
          token_type_hint: "refresh_token",
        )
      end

    assert_predicate result, :success?
    assert_predicate grant.reload, :revoked?
    assert_predicate revoked_grant_root.reload, :currently_usable?
    assert_predicate other_root.reload, :currently_usable?
    assert_predicate other_device.reload, :usable?
  end

  test "refresh reuse revokes only the grant and leaves other browser sessions active" do
    principal_public_id = PublicId.generate
    reused_grant_root, = create_app_root(principal_public_id)
    other_root, other_device = create_app_root(principal_public_id)
    grant = OpAppGrant.create!(
      authentication_epoch: reused_grant_root.authentication_epoch,
      client_token_id: reused_grant_root.id,
      device_session_id: reused_grant_root.device_session_id,
      oidc_client_id: "core-app-jp",
      oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid,
      refresh_token_expires_at: 1.hour.from_now,
    )
    first_refresh_token = grant.issue_refresh_token!

    rotation = OidcRefreshTokenIssuer.call(refresh_token: first_refresh_token, resource_type: "client")
    replay = OidcRefreshTokenIssuer.call(refresh_token: first_refresh_token, resource_type: "client")

    assert_predicate rotation, :success?
    assert_equal :refresh_token_reuse_detected, replay.reason
    assert_predicate grant.reload, :revoked?
    assert_predicate reused_grant_root.reload, :currently_usable?
    assert_predicate other_root.reload, :currently_usable?
    assert_predicate other_device.reload, :usable?
  end

  private

  def create_app_root(principal_public_id)
    device = ClientDeviceSession.create!(subject_public_id: principal_public_id)
    root = ClientToken.create!(authentication_epoch: 0, device_session: device, subject_public_id: principal_public_id)

    [root, device]
  end
end
