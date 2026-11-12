# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    # Credential persistence belongs to Governance; Access has no local Passkey writer.
    class PasskeyRegistrationWriterInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      DIRECT_WRITE =
        /\b(?:ClientPasskey|OperatorPasskey|(?:client|staff|operator)_passkeys)
          \.(?:create!?|create_with|find_or_create_by!?|create_or_find_by!?|insert_all!?|insert!?|upsert_all|upsert)\b/x

      test "application code does not write local Passkey records" do
        offenders =
          Rails.root.glob("{app,lib}/**/*.rb").flat_map do |path|
            path.each_line.with_index(1).filter_map do |line, number|
              "#{path.relative_path_from(Rails.root)}:#{number}" if line.match?(DIRECT_WRITE)
            end
          end

        assert_empty offenders, "Passkey persistence belongs to Governance"
      end
    end
  end
end
