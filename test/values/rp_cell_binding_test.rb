# frozen_string_literal: true

require "test_helper"

class RpCellBindingTest < ActiveSupport::TestCase
  test "client lookup resolves only to the fixed RP connection inventory" do
    RpCellBinding::CELLS.each_value do |cell|
      assert_equal cell, RpCellBinding.for_client(cell.client_id)
    end

    assert_equal RpCellBinding::CELLS.keys, RpCellBinding.connections
    assert_raises(RpCellBinding::UnknownCell) { RpCellBinding.for_client("unconfigured-client") }
  end
end
