# frozen_string_literal: true

class SeedClientStepUpEvidenceStates < ActiveRecord::Migration[8.2]
  def up
    # Fixed reference data is separate from schema construction.
    safety_assured { execute("INSERT INTO client_step_up_evidence_states (id) VALUES (10), (20)") }
  end

  def down
    safety_assured { execute("DELETE FROM client_step_up_evidence_states WHERE id IN (10, 20)") }
  end
end
