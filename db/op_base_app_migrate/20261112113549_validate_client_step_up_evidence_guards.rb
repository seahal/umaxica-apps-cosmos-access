# frozen_string_literal: true

class ValidateClientStepUpEvidenceGuards < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    validate_check_constraint(:client_tokens, name: "ck_client_token_uv_present")
    validate_check_constraint(:client_tokens, name: "ck_client_token_full_present")
    validate_check_constraint(:client_step_up_ceremony_transactions, name: "ck_client_ceremony_uv_present")
    validate_check_constraint(:client_tokens, name: "ck_client_token_evidence_state")
    validate_check_constraint(:client_step_up_ceremony_transactions, name: "ck_client_ceremony_evidence_state")
    validate_check_constraint(:client_step_up_ceremony_transactions, name: "ck_client_ceremony_evidence_lifecycle")
    validate_foreign_key(:client_tokens, name: "fk_client_token_step_up_evidence_state")
    validate_foreign_key(:client_step_up_ceremony_transactions, name: "fk_client_ceremony_step_up_evidence_state")
  end

  def down
    transaction do
      restore_token_guards
      restore_ceremony_guards
      restore_reference_validation
    end
  end

  private

  def restore_token_guards
    remove_check_constraint(:client_tokens, name: "ck_client_token_uv_present")
    add_check_constraint(
      :client_tokens, "last_step_up_user_verified IS NOT NULL", name: "ck_client_token_uv_present", validate: false,
    )
    remove_check_constraint(:client_tokens, name: "ck_client_token_full_present")
    add_check_constraint(
      :client_tokens, "last_step_up_full_reauthentication IS NOT NULL", name: "ck_client_token_full_present", validate: false,
    )
    remove_check_constraint(:client_tokens, name: "ck_client_token_evidence_state")
    add_check_constraint(
      :client_tokens, "evidence_state_id <> 10 OR (last_step_up_user_verified = false AND last_step_up_full_reauthentication = false)", name: "ck_client_token_evidence_state", validate: false,
    )
  end

  def restore_ceremony_guards
    remove_check_constraint(:client_step_up_ceremony_transactions, name: "ck_client_ceremony_uv_present")
    add_check_constraint(
      :client_step_up_ceremony_transactions, "user_verified IS NOT NULL", name: "ck_client_ceremony_uv_present", validate: false,
    )
    remove_check_constraint(:client_step_up_ceremony_transactions, name: "ck_client_ceremony_evidence_state")
    add_check_constraint(
      :client_step_up_ceremony_transactions, "evidence_state_id <> 10 OR user_verified = false", name: "ck_client_ceremony_evidence_state", validate: false,
    )
    remove_check_constraint(:client_step_up_ceremony_transactions, name: "ck_client_ceremony_evidence_lifecycle")
    add_check_constraint(
      :client_step_up_ceremony_transactions, "(status <> 'pending' OR evidence_state_id = 10) AND (status NOT IN ('verified', 'consumed') OR evidence_state_id = 20)", name: "ck_client_ceremony_evidence_lifecycle", validate: false,
    )
  end

  def restore_reference_validation
    remove_foreign_key(:client_tokens, name: "fk_client_token_step_up_evidence_state")
    add_foreign_key(
      :client_tokens, :client_step_up_evidence_states, column: :evidence_state_id,
                                                       name: "fk_client_token_step_up_evidence_state", on_delete: :restrict, validate: false,
    )
    remove_foreign_key(:client_step_up_ceremony_transactions, name: "fk_client_ceremony_step_up_evidence_state")
    add_foreign_key(
      :client_step_up_ceremony_transactions, :client_step_up_evidence_states, column: :evidence_state_id,
                                                                              name: "fk_client_ceremony_step_up_evidence_state", on_delete: :restrict, validate: false,
    )
  end
end
