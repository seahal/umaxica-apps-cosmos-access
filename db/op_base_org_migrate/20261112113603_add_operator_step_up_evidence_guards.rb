# frozen_string_literal: true

class AddOperatorStepUpEvidenceGuards < ActiveRecord::Migration[8.2]
  def change
    add_check_constraint(
      :operator_tokens, "last_step_up_user_verified IS NOT NULL", name: "ck_operator_token_uv_present", validate: false,
    )
    add_check_constraint(
      :operator_tokens, "last_step_up_full_reauthentication IS NOT NULL", name: "ck_operator_token_full_present", validate: false,
    )
    add_check_constraint(
      :operator_step_up_ceremony_transactions, "user_verified IS NOT NULL", name: "ck_operator_ceremony_uv_present", validate: false,
    )
    add_check_constraint(
      :operator_tokens, "evidence_state_id <> 10 OR (last_step_up_user_verified = false AND last_step_up_full_reauthentication = false)", name: "ck_operator_token_evidence_state", validate: false,
    )
    add_check_constraint(
      :operator_step_up_ceremony_transactions, "evidence_state_id <> 10 OR user_verified = false", name: "ck_operator_ceremony_evidence_state", validate: false,
    )
    add_check_constraint(
      :operator_step_up_ceremony_transactions, "(status <> 'pending' OR evidence_state_id = 10) AND (status NOT IN ('verified', 'consumed') OR evidence_state_id = 20)", name: "ck_operator_ceremony_evidence_lifecycle", validate: false,
    )
  end
end
