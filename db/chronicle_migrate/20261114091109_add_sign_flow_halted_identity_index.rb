# frozen_string_literal: true

class AddSignFlowHaltedIdentityIndex < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    add_index :operator_chronicles,
              %i[sign_flow_halted_transaction_public_id sign_flow_halted_generation],
              unique: true, where: "event_id = 18",
              name: "uniq_operator_chronicles_sign_flow_halted_identity",
              algorithm: :concurrently
  end

  def down
    remove_index :operator_chronicles,
                 name: "uniq_operator_chronicles_sign_flow_halted_identity",
                 algorithm: :concurrently
  end
end
