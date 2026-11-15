# frozen_string_literal: true

require "test_helper"

class SignUpCancellationTest < ActiveSupport::TestCase
  test "cancellation stays unavailable until Governance owns the termination decision" do
    error =
      assert_raises(GovernanceLookupUnavailableError) do
        SignUpCancellation.call(cycle: nil, actor_context: nil)
      end

    assert_equal "Governance sign-up termination authority is unavailable", error.message
  end
end
