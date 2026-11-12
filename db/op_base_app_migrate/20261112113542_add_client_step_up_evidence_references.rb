# frozen_string_literal: true

class AddClientStepUpEvidenceReferences < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    add_reference(
      :client_tokens, :evidence_state, null: false, default: 10, index: { algorithm: :concurrently },
                                       foreign_key: { to_table: :client_step_up_evidence_states, name: "fk_client_token_step_up_evidence_state", on_delete: :restrict, validate: false },
    )
    add_reference(
      :client_step_up_ceremony_transactions, :evidence_state, null: false, default: 10, index: { algorithm: :concurrently },
                                                              foreign_key: { to_table: :client_step_up_evidence_states, name: "fk_client_ceremony_step_up_evidence_state", on_delete: :restrict, validate: false },
    )
  end
end
