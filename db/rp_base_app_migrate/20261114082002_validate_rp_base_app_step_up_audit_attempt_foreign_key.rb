# frozen_string_literal: true

class ValidateRpBaseAppStepUpAuditAttemptForeignKey < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    validate_foreign_key(:rp_step_up_audit_outbox_attempts, :rp_step_up_audit_outboxes, name: "fk_rails_9735bc9c9b")
  end

  def down
    transaction do
      remove_foreign_key(:rp_step_up_audit_outbox_attempts, name: "fk_rails_9735bc9c9b")
      add_foreign_key(
        :rp_step_up_audit_outbox_attempts, :rp_step_up_audit_outboxes,
        column: :outbox_id, name: "fk_rails_9735bc9c9b", on_delete: :restrict, validate: false,
      )
    end
  end
end
