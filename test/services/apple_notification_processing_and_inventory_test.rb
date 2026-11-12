# typed: false
# frozen_string_literal: true

require "test_helper"

class AppleNotificationProcessingAndInventoryTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  # Two availability slots claiming the same hostname would leave the switch that
  # answers for it undefined, so the registry refuses to build at all.
  test "a hostname claimed by two availability slots is refused by name" do
    registry = FqdnAvailabilityRegistry.dup
    # `Module#dup` copies instance variables, so a registry whose `@index` was
    # already memoized -- anything that resolved a hostname earlier in the
    # process does that -- hands the copy a built index and `index` never runs.
    # Drop the inherited memo so the duplicate builds from the slots below.
    registry.remove_instance_variable(:@index) if registry.instance_variable_defined?(:@index)
    slot = Struct.new(:name, :hostnames)
    registry.define_singleton_method(:slots) do
      [slot.new(:first, %w(shared.example.test)), slot.new(:second, %w(shared.example.test))]
    end

    error = assert_raises(ArgumentError) { registry.slot_for("shared.example.test") }

    assert_match(/claimed by both/, error.message)
  end
end
