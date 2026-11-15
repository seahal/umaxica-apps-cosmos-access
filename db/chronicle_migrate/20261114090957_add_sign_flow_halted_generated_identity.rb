# frozen_string_literal: true

class AddSignFlowHaltedGeneratedIdentity < ActiveRecord::Migration[8.2]
  def up
    unless connection.database_version >= 12_00_00
      raise ActiveRecord::MigrationError, "sign-flow-halted generated columns require PostgreSQL 12 or later"
    end

    add_column :operator_chronicles, :sign_flow_halted_transaction_public_id, :text,
               as: "CASE WHEN event_id = 18 THEN context ->> 'transaction_public_id' END", stored: true
    add_column :operator_chronicles, :sign_flow_halted_generation, :text,
               as: "CASE WHEN event_id = 18 THEN context ->> 'halt_generation' END", stored: true
  end

  def down
    remove_column :operator_chronicles, :sign_flow_halted_generation
    remove_column :operator_chronicles, :sign_flow_halted_transaction_public_id
  end
end
