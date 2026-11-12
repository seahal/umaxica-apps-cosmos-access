# frozen_string_literal: true

class AddClientStepUpEvidenceGuards < ActiveRecord::Migration[8.2]
  def change
    add_check_constraint(
      :client_tokens, "last_step_up_user_verified IS NOT NULL", name: "ck_client_token_uv_present", validate: false,
    )
    add_check_constraint(
      :client_tokens, "last_step_up_full_reauthentication IS NOT NULL", name: "ck_client_token_full_present", validate: false,
    )
    add_check_constraint(
      :client_step_up_ceremony_transactions, "user_verified IS NOT NULL", name: "ck_client_ceremony_uv_present", validate: false,
    )
    add_check_constraint(
      :client_tokens, "evidence_state_id <> 10 OR (last_step_up_user_verified = false AND last_step_up_full_reauthentication = false)", name: "ck_client_token_evidence_state", validate: false,
    )
    add_check_constraint(
      :client_step_up_ceremony_transactions, "evidence_state_id <> 10 OR user_verified = false", name: "ck_client_ceremony_evidence_state", validate: false,
    )
    add_check_constraint(
      :client_step_up_ceremony_transactions, "(status <> 'pending' OR evidence_state_id = 10) AND (status NOT IN ('verified', 'consumed') OR evidence_state_id = 20)", name: "ck_client_ceremony_evidence_lifecycle", validate: false,
    )
  end
end
