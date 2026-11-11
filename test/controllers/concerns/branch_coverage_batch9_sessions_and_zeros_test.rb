# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch9SessionsAndZerosTest < ActiveSupport::TestCase
  test "SecurityConsumedJti and SessionLimitResolutionTokenRef blank guards" do
    assert_not SecurityConsumedJti.consume!(purpose: "", issuer: "x", jti: "y", expires_at: 1.hour.from_now)
    assert_nil SessionLimitResolutionTokenRef.find_client_token("")
  end
end
