# frozen_string_literal: true

require "test_helper"

class GovernanceRevocationReceiptOrderTest < ActiveSupport::TestCase
  [
    [OpAppGovernanceRevocationReceipt, "app", "cli_example"],
    [OpOrgGovernanceRevocationReceipt, "org", "opr_example"],
  ].each do |model, realm, subject|
    test "#{realm} receipts use recorded time and UUID to order first and last deterministically" do
      earlier_id = "ffffffff-ffff-4fff-8fff-ffffffffffff"
      later_id = "00000000-0000-4000-8000-000000000001"
      same_time_id = "00000000-0000-4000-8000-000000000002"
      time = Time.utc(2026, 1, 1)
      command = { realm: realm, sub: subject, scope: "all_sessions", actor: subject, reason: "security" }
      [
        [earlier_id, time], [later_id, time + 1.second], [same_time_id, time + 1.second],
      ].each do |command_id, committed_at|
        model.create!(
          command_id: command_id, issuer: "https://governance.example", command_digest: "a" * 32,
          command: command, committed_at: committed_at,
        )
      end
      scope = model.where(command_id: [earlier_id, later_id, same_time_id])

      assert_equal earlier_id, scope.first.command_id
      assert_equal same_time_id, scope.last.command_id
      assert_equal [earlier_id, later_id, same_time_id], scope.first(3).map(&:command_id)
    end
  end
end
