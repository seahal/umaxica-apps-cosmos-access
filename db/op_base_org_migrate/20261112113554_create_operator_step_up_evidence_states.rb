# frozen_string_literal: true

class CreateOperatorStepUpEvidenceStates < ActiveRecord::Migration[8.2]
  def change
    create_table(:operator_step_up_evidence_states, id: :bigint)
    add_check_constraint(:operator_step_up_evidence_states, "id IN (10, 20)", name: "ck_operator_step_up_evidence_states_ids")
  end
end
