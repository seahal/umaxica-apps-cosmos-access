# frozen_string_literal: true

class RemoveRedundantRpBaseOrgStepUpIndexes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    remove_index :rp_step_up_audit_outbox_attempts,
                 name: "index_rp_step_up_audit_outbox_attempts_on_outbox_id",
                 algorithm: :concurrently
    remove_index :rp_step_up_audit_outboxes,
                 name: "index_rp_step_up_audit_outboxes_on_delivery_state_id",
                 algorithm: :concurrently
  end

  def down
    add_index :rp_step_up_audit_outbox_attempts, :outbox_id,
              name: "index_rp_step_up_audit_outbox_attempts_on_outbox_id",
              algorithm: :concurrently
    add_index :rp_step_up_audit_outboxes, :delivery_state_id,
              name: "index_rp_step_up_audit_outboxes_on_delivery_state_id",
              algorithm: :concurrently
  end
end

