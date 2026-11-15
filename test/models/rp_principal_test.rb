# frozen_string_literal: true

require "test_helper"

class RpPrincipalTest < ActiveSupport::TestCase
  test "cell principals use the shared self-only policy and local disablement" do
    principal = RpBaseAppPrincipal.new

    assert_equal RpPrincipalPolicy, principal.policy_class
    assert_not_predicate principal, :deactivated?

    principal.disabled_at = Time.current

    assert_predicate principal, :deactivated?
  end
end
