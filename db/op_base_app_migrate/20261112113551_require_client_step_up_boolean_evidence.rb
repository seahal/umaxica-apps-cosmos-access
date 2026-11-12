# frozen_string_literal: true

class RequireClientStepUpBooleanEvidence < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!
  def up
    change_column_null(:client_tokens, :last_step_up_user_verified, false)
    change_column_default(:client_tokens, :last_step_up_user_verified, from: nil, to: false)
    remove_check_constraint(:client_tokens, name: "ck_client_token_uv_present")
    change_column_null(:client_tokens, :last_step_up_full_reauthentication, false)
    change_column_default(:client_tokens, :last_step_up_full_reauthentication, from: nil, to: false)
    remove_check_constraint(:client_tokens, name: "ck_client_token_full_present")
    change_column_null(:client_step_up_ceremony_transactions, :user_verified, false)
    change_column_default(:client_step_up_ceremony_transactions, :user_verified, from: nil, to: false)
    remove_check_constraint(:client_step_up_ceremony_transactions, name: "ck_client_ceremony_uv_present")
  end

  def down
    add_check_constraint(:client_step_up_ceremony_transactions, "user_verified IS NOT NULL", name: "ck_client_ceremony_uv_present", validate: false)
    validate_check_constraint(:client_step_up_ceremony_transactions, name: "ck_client_ceremony_uv_present")
    change_column_null(:client_step_up_ceremony_transactions, :user_verified, true)
    change_column_default(:client_step_up_ceremony_transactions, :user_verified, from: false, to: nil)
    add_check_constraint(:client_tokens, "last_step_up_full_reauthentication IS NOT NULL", name: "ck_client_token_full_present", validate: false)
    validate_check_constraint(:client_tokens, name: "ck_client_token_full_present")
    change_column_null(:client_tokens, :last_step_up_full_reauthentication, true)
    change_column_default(:client_tokens, :last_step_up_full_reauthentication, from: false, to: nil)
    add_check_constraint(:client_tokens, "last_step_up_user_verified IS NOT NULL", name: "ck_client_token_uv_present", validate: false)
    validate_check_constraint(:client_tokens, name: "ck_client_token_uv_present")
    change_column_null(:client_tokens, :last_step_up_user_verified, true)
    change_column_default(:client_tokens, :last_step_up_user_verified, from: false, to: nil)
  end
end
