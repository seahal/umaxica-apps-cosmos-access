# frozen_string_literal: true

class RestrictRpBaseAppStepUpStateHistoryDeletion < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    transaction do
      remove_foreign_key(:rp_step_up_state_transitions, name: "fk_rails_42bc1ac3a0")
      add_foreign_key(
        :rp_step_up_state_transitions, :rp_step_up_states,
        column: :owner_id, name: "fk_rails_42bc1ac3a0", on_delete: :restrict, validate: false,
      )
    end
  end

  def down
    transaction do
      remove_foreign_key(:rp_step_up_state_transitions, name: "fk_rails_42bc1ac3a0")
      add_foreign_key(
        :rp_step_up_state_transitions, :rp_step_up_states,
        column: :owner_id, name: "fk_rails_42bc1ac3a0", on_delete: :cascade, validate: false,
      )
    end

    validate_foreign_key(:rp_step_up_state_transitions, :rp_step_up_states, name: "fk_rails_42bc1ac3a0")
  end
end
