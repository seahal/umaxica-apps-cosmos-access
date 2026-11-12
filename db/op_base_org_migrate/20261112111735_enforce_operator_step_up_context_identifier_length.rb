# frozen_string_literal: true

class EnforceOperatorStepUpContextIdentifierLength < ActiveRecord::Migration[8.2]
  def change
    add_check_constraint(
      :operator_step_up_contexts, "char_length(public_id) = 21",
      name: "operator_step_up_contexts_public_id_length", validate: false,
    )
  end
end
