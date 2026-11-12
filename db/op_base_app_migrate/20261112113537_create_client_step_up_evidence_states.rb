# frozen_string_literal: true

class CreateClientStepUpEvidenceStates < ActiveRecord::Migration[8.2]
  def change
    create_table(:client_step_up_evidence_states, id: :bigint)
    add_check_constraint(:client_step_up_evidence_states, "id IN (10, 20)", name: "ck_client_step_up_evidence_states_ids")
  end
end
