# frozen_string_literal: true

class RemoveRedundantOpOrgIndexes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    # Retain all-row leading-key access through the existing composite indexes, and keep the
    # Rails reference index for delivery_state_id instead of its identical ordinary duplicate.
    remove_index(
      :operator_step_up_commits, name: "index_operator_step_up_commits_on_root_token_id",
                                 algorithm: :concurrently,
    )
    remove_index(
      :operator_step_up_audit_outbox_attempts, name: "index_operator_step_up_audit_outbox_attempts_on_outbox_id",
                                               algorithm: :concurrently,
    )
    remove_index(
      :operator_step_up_audit_outboxes, name: "idx_operator_step_up_audit_outboxes_delivery",
                                        algorithm: :concurrently,
    )
    remove_index(
      :op_org_authority_stop_participants, name: "index_op_org_authority_stop_participants_on_stop_id",
                                           algorithm: :concurrently,
    )
  end

  def down
    add_index(
      :op_org_authority_stop_participants, :stop_id,
      name: "index_op_org_authority_stop_participants_on_stop_id", algorithm: :concurrently,
    )
    add_index(
      :operator_step_up_audit_outboxes, :delivery_state_id,
      name: "idx_operator_step_up_audit_outboxes_delivery", algorithm: :concurrently,
    )
    add_index(
      :operator_step_up_audit_outbox_attempts, :outbox_id,
      name: "index_operator_step_up_audit_outbox_attempts_on_outbox_id", algorithm: :concurrently,
    )
    add_index(
      :operator_step_up_commits, :root_token_id,
      name: "index_operator_step_up_commits_on_root_token_id", algorithm: :concurrently,
    )
  end
end
