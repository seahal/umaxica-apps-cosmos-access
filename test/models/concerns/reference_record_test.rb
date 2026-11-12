# typed: false
# frozen_string_literal: true

require "test_helper"

class ReferenceRecordTest < ActiveSupport::TestCase
  class DummyReference < ApplicationRecord
    # We create a simple class mimicking a reference table.
    # Usually they have just an id, but for tests we don't have a table.
    # Use retained OP token status tables for the real reference model checks.
  end

  test "record_timestamps is false" do
    assert_not ClientTokenStatus.record_timestamps
    assert_not OperatorTokenStatus.record_timestamps
  end

  test "nothing_id returns NOTHING constant" do
    assert_equal ClientTokenStatus::NOTHING, ClientTokenStatus.nothing_id
    assert_equal OperatorTokenStatus::NOTHING, OperatorTokenStatus.nothing_id
  end
end
