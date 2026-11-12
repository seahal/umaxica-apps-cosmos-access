# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch9SessionsAndZerosTest < ActiveSupport::TestCase
  test "SecurityConsumedJti blank guard" do
    assert_not SecurityConsumedJti.consume!(purpose: "", issuer: "x", jti: "y", expires_at: 1.hour.from_now)
  end
end
