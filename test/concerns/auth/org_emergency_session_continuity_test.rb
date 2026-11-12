# frozen_string_literal: true

require "test_helper"

class Auth::OrgEmergencySessionContinuityTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(operator_tokens operator_device_sessions)

  test "repeated browser refresh preserves standby authentication context" do
    root = OperatorToken.find(ActiveRecord::FixtureSet.identify(:one))
    root.update!(authentication_context: "standby")
    refresh = root.rotate_refresh_token!

    3.times do
      result = AuthRefreshTokenIssuer.call(refresh_token: refresh, resource_type: "operator")

      assert_predicate result, :success?, result.reason.to_s
      assert_equal "standby", result.token.reload.authentication_context
      refresh = result.refresh_token
    end
  end

  test "app sessions report normal authentication context" do
    assert_not_includes ClientToken.column_names, "authentication_context"
    assert_predicate ClientToken.new.authentication_context_value, :normal?
    assert_not_predicate ClientToken.new, :standby_authentication_context?
  end
end
