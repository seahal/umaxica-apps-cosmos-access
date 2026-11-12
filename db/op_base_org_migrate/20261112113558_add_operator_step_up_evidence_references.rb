# frozen_string_literal: true

class AddOperatorStepUpEvidenceReferences < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_reference(
      :operator_tokens, :evidence_state, null: false, default: 10, index: { algorithm: :concurrently },
                                         foreign_key: { to_table: :operator_step_up_evidence_states, name: "fk_operator_token_step_up_evidence_state", on_delete: :restrict, validate: false },
    )
    add_reference(
      :operator_step_up_ceremony_transactions, :evidence_state, null: false, default: 10, index: { algorithm: :concurrently },
                                                                foreign_key: { to_table: :operator_step_up_evidence_states, name: "fk_operator_ceremony_step_up_evidence_state", on_delete: :restrict, validate: false },
    )
  end
end
