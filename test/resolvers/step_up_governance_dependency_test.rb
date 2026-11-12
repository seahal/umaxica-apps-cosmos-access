# frozen_string_literal: true

require "test_helper"

class StepUpGovernanceDependencyTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(client_tokens operator_tokens client_device_sessions operator_device_sessions)

  test "required step-up cannot treat a missing Governance security policy as normal mode" do
    [ClientToken, OperatorToken].each do |model|
      token = model.find(ActiveRecord::FixtureSet.identify(:one))
      original_evidence = token.attributes.slice("evidence_state_id", "last_step_up_at")

      error =
        assert_raises(GovernanceLookupUnavailableError) do
          StepUpResolver.call(token: token, scope: "settings_email")
        end

      assert_equal "Governance step-up policy lookup is unavailable", error.message
      assert_equal original_evidence, token.reload.attributes.slice("evidence_state_id", "last_step_up_at")
    end
  end
end
