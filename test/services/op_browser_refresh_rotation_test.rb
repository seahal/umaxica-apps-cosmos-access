# frozen_string_literal: true

require "test_helper"

class OpBrowserRefreshRotationTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(client_tokens operator_tokens client_device_sessions operator_device_sessions)

  test "typed browser rotation preserves identity and rolls back when response construction fails" do
    [["client", ClientToken], ["operator", OperatorToken]].each do |type, root_class|
      root = root_class.includes(:device_session).find(ActiveRecord::FixtureSet.identify(:one))
      root.update!(authentication_context: "normal") if type == "operator"
      original = root.rotate_refresh_token!
      original_id = root.id
      before = root_class.count

      assert_raises(RuntimeError) do
        AuthRefreshTokenIssuer.call(
          refresh_token: original, resource_type: type,
          response_builder: ->(*) { raise RuntimeError, "response signing unavailable" },
        )
      end

      assert_nil root.reload.rotated_at
      assert_equal original_id, root.device_session.reload.current_refresh_token_id
      assert_equal before, root_class.count
      result = AuthRefreshTokenIssuer.call(
        refresh_token: original, resource_type: type,
        response_builder: ->(replacement, _) { { principal: replacement.principal_public_id } },
      )

      assert_predicate result, :success?, result.reason.to_s
      assert_equal root.principal_public_id, result.response.fetch(:principal)
      assert_equal root.device_session_id, result.token.device_session_id
      assert_not_equal original, result.refresh_token
      assert_equal result.token.id, root.device_session.reload.current_refresh_token_id
    end
  end

  test "wrong realm cannot find or rotate a browser refresh credential" do
    root = ClientToken.find(ActiveRecord::FixtureSet.identify(:one))
    original = root.rotate_refresh_token!
    result = AuthRefreshTokenIssuer.call(refresh_token: original, resource_type: "operator")

    assert_not result.success?
    assert_nil root.reload.rotated_at
    assert_equal root.id, root.device_session.reload.current_refresh_token_id
  end

  test "browser refresh replay stops its real device and grants without retired identity models" do
    [["client", ClientToken, OpAppGrant], ["operator", OperatorToken, OpOrgGrant]].each do |type, roots, grants|
      root = roots.includes(:device_session).find(ActiveRecord::FixtureSet.identify(:one))
      root.update!(authentication_context: "normal") if type == "operator"
      grant = grants.create!(
        **((type == "client") ? { client_token_id: root.id } : { operator_token_id: root.id }),
        device_session_id: root.device_session_id,
        authentication_epoch: root.authentication_epoch,
        oidc_client_id: ((type == "client") ? "core-app-jp" : "core-org-jp"),
        refresh_token_expires_at: 1.hour.from_now,
      )
      original = root.rotate_refresh_token!
      rotation = AuthRefreshTokenIssuer.call(refresh_token: original, resource_type: type)

      assert_predicate rotation, :success?, rotation.reason.to_s
      result = AuthRefreshTokenIssuer.call(refresh_token: original, resource_type: type)

      assert_not result.success?
      assert_equal :refresh_token_reuse_detected, result.reason
      assert_predicate rotation.token.reload, :revoked?
      assert_not root.device_session.reload.usable?
      assert_predicate grant.reload, :revoked?
      sibling = roots.find(ActiveRecord::FixtureSet.identify(:two))

      assert_not sibling.revoked?
    end
  end
end
