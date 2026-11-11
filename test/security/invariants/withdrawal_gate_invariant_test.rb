# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    class WithdrawalGateInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      test "application controllers do not skip the withdrawal gate" do
        offenders =
          Rails.root.glob("app/controllers/**/*.rb").flat_map do |path|
            content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)

            content.each_line.with_index(1).filter_map do |line, line_number|
              next unless line.match?(/skip_before_action\s+:enforce_withdrawal_gate!/)

              "#{relative_path}:#{line_number}: #{line.strip}"
            end
          end

        assert_empty offenders, "Withdrawal gate skips require explicit invariant allowlist:\n#{offenders.join("\n")}"
      end
    end
  end
end
