# frozen_string_literal: true

class ValidateOpAppHistoricalForeignKeys < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  # Historical creation omitted validation; reconstruction must verify existing rows too.
  def up
    validate_foreign_key(:client_verifications, name: "fk_rails_18a774c144")
    validate_foreign_key(:client_auth_admission_bindings, name: "fk_rails_39848a51b7")
    validate_foreign_key(:client_sign_up_flows, name: "fk_rails_533362926d")
    validate_foreign_key(:client_step_up_sessions, name: "fk_rails_64ec203fd3")
    validate_foreign_key(:client_sign_up_flows, name: "fk_rails_9b0b63a0c6")
    validate_foreign_key(:client_sign_in_flows, name: "fk_rails_bd772deef1")
    validate_foreign_key(:client_tokens, name: "fk_rails_c11b41180d")
    validate_foreign_key(:client_tokens, name: "fk_rails_f69bf5b8f0")
    validate_foreign_key(:client_tokens, name: "fk_user_tokens_on_user_token_binding_method_id")
    validate_foreign_key(:client_tokens, name: "fk_user_tokens_on_user_token_dbsc_status_id")
  end

  def down
    # Restore validation metadata atomically while retaining enforcement and deletion actions.
    transaction do
      restore_token_catalog_references
      restore_workflow_references
    end
  end

  private

  def restore_token_catalog_references
    remove_foreign_key(:client_tokens, name: "fk_user_tokens_on_user_token_dbsc_status_id")
    add_foreign_key(
      :client_tokens, :client_token_dbsc_statuses, column: :user_token_dbsc_status_id,
                                                   name: "fk_user_tokens_on_user_token_dbsc_status_id", validate: false,
    )
    remove_foreign_key(:client_tokens, name: "fk_user_tokens_on_user_token_binding_method_id")
    add_foreign_key(
      :client_tokens, :client_token_binding_methods, column: :user_token_binding_method_id,
                                                     name: "fk_user_tokens_on_user_token_binding_method_id", validate: false,
    )
    remove_foreign_key(:client_tokens, name: "fk_rails_f69bf5b8f0")
    add_foreign_key(
      :client_tokens, :client_token_kinds, column: :user_token_kind_id,
                                           name: "fk_rails_f69bf5b8f0", validate: false, on_delete: :restrict,
    )
    remove_foreign_key(:client_tokens, name: "fk_rails_c11b41180d")
    add_foreign_key(
      :client_tokens, :client_token_statuses, column: :user_token_status_id,
                                              name: "fk_rails_c11b41180d", validate: false, on_delete: :restrict,
    )
  end

  def restore_workflow_references
    remove_foreign_key(:client_sign_in_flows, name: "fk_rails_bd772deef1")
    add_foreign_key(
      :client_sign_in_flows, :client_tokens, column: :token_id,
                                             name: "fk_rails_bd772deef1", validate: false, on_delete: :cascade,
    )
    remove_foreign_key(:client_sign_up_flows, name: "fk_rails_9b0b63a0c6")
    add_foreign_key(
      :client_sign_up_flows, :client_sign_up_flow_cleanup_statuses, column: :cleanup_status_id,
                                                                    name: "fk_rails_9b0b63a0c6", validate: false,
    )
    remove_foreign_key(:client_step_up_sessions, name: "fk_rails_64ec203fd3")
    add_foreign_key(
      :client_step_up_sessions, :client_tokens, column: :user_token_id,
                                                name: "fk_rails_64ec203fd3", validate: false, on_delete: :cascade,
    )
    remove_foreign_key(:client_sign_up_flows, name: "fk_rails_533362926d")
    add_foreign_key(
      :client_sign_up_flows, :client_sign_up_flow_statuses, column: :status_id,
                                                            name: "fk_rails_533362926d", validate: false, on_delete: :restrict,
    )
    remove_foreign_key(:client_auth_admission_bindings, name: "fk_rails_39848a51b7")
    add_foreign_key(
      :client_auth_admission_bindings, :client_auth_ceremony_sessions, column: :auth_ceremony_session_id,
                                                                       name: "fk_rails_39848a51b7", validate: false, on_delete: :restrict,
    )
    remove_foreign_key(:client_verifications, name: "fk_rails_18a774c144")
    add_foreign_key(
      :client_verifications, :client_tokens, column: :user_token_id,
                                             name: "fk_rails_18a774c144", validate: false, on_delete: :cascade,
    )
  end
end
