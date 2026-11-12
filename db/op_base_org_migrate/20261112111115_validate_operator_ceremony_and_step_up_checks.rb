# frozen_string_literal: true

class ValidateOperatorCeremonyAndStepUpChecks < ActiveRecord::Migration[8.2]
  def up
    validate_check_constraint(:operator_step_up_sessions, name: :chk_staff_step_up_sessions_retention_order)
    validate_check_constraint(:operator_email_ceremony_transactions, name: :chk_operator_email_ceremony_evp_attempt_count)
  end

  def down
    remove_check_constraint(:operator_email_ceremony_transactions, name: :chk_operator_email_ceremony_evp_attempt_count)
    add_check_constraint(
      :operator_email_ceremony_transactions, "evp_attempt_count >= 0",
      name: :chk_operator_email_ceremony_evp_attempt_count, validate: false,
    )

    remove_check_constraint(:operator_step_up_sessions, name: :chk_staff_step_up_sessions_retention_order)
    add_check_constraint(
      :operator_step_up_sessions, "discard_at <= purge_eligible_at",
      name: :chk_staff_step_up_sessions_retention_order, validate: false,
    )
  end
end
