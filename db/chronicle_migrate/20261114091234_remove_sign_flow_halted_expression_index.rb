# frozen_string_literal: true

class RemoveSignFlowHaltedExpressionIndex < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    remove_index :operator_chronicles,
                 name: "uniq_operator_chronicles_sign_flow_halted",
                 algorithm: :concurrently
  end

  def down
    add_index :operator_chronicles,
              "(context->>'transaction_public_id'), (context->>'halt_generation')",
              unique: true, where: "event_id = 18",
              name: "uniq_operator_chronicles_sign_flow_halted",
              algorithm: :concurrently
  end
end
