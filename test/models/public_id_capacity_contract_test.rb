# frozen_string_literal: true

require "test_helper"

class PublicIdCapacityContractTest < ActiveSupport::TestCase
  # Logout transactions retain the earlier 25-character capacity contract.
  test "logout transactions have their public identity length constraint" do
    OpBaseAppRecord.connection_pool.with_connection do |connection|
      constraint =
        connection.check_constraints("logout_transactions").find do |item|
          item.name == "logout_transactions_public_id_max_length"
        end

      assert constraint, "logout_transactions_public_id_max_length must be registered on logout_transactions"
      assert_match(/char_length\(public_id(?:::text)?\) <= 25/, constraint.expression)
    end
  end
end
