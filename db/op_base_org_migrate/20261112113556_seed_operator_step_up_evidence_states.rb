# frozen_string_literal: true

class SeedOperatorStepUpEvidenceStates < ActiveRecord::Migration[8.2]
  def up
    # Fixed reference data is separate from schema construction.
    safety_assured { execute("INSERT INTO operator_step_up_evidence_states (id) VALUES (10), (20)") }
  end

  def down
    safety_assured { execute("DELETE FROM operator_step_up_evidence_states WHERE id IN (10, 20)") }
  end
end
