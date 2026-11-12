# frozen_string_literal: true

class ValidateOpOrgHistoricalForeignKeys < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  # Historical creation omitted validation; reconstruction must verify existing rows too.
  def up
    validate_foreign_key(:operator_sign_in_flows, name: "fk_rails_0451f7d1d6")
    validate_foreign_key(:operator_sign_up_flows, name: "fk_rails_10f95a7068")
    validate_foreign_key(:operator_tokens, name: "fk_rails_1a807f181b")
    validate_foreign_key(:operator_step_up_sessions, name: "fk_rails_6daa6fb880")
    validate_foreign_key(:operator_auth_admission_bindings, name: "fk_rails_781188228f")
    validate_foreign_key(:operator_verifications, name: "fk_rails_c8ab8d08df")
    validate_foreign_key(:operator_tokens, name: "fk_rails_f211b6bc2e")
    validate_foreign_key(:operator_sign_up_flows, name: "fk_rails_fb3acc316b")
    validate_foreign_key(:operator_tokens, name: "fk_staff_tokens_on_staff_token_binding_method_id")
    validate_foreign_key(:operator_tokens, name: "fk_staff_tokens_on_staff_token_dbsc_status_id")
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
    remove_foreign_key(:operator_tokens, name: "fk_staff_tokens_on_staff_token_dbsc_status_id")
    add_foreign_key(
      :operator_tokens, :operator_token_dbsc_statuses, column: :staff_token_dbsc_status_id,
                                                       name: "fk_staff_tokens_on_staff_token_dbsc_status_id", validate: false,
    )
    remove_foreign_key(:operator_tokens, name: "fk_staff_tokens_on_staff_token_binding_method_id")
    add_foreign_key(
      :operator_tokens, :operator_token_binding_methods, column: :staff_token_binding_method_id,
                                                         name: "fk_staff_tokens_on_staff_token_binding_method_id", validate: false,
    )
    remove_foreign_key(:operator_tokens, name: "fk_rails_f211b6bc2e")
    add_foreign_key(
      :operator_tokens, :operator_token_kinds, column: :staff_token_kind_id,
                                               name: "fk_rails_f211b6bc2e", validate: false, on_delete: :restrict,
    )
    remove_foreign_key(:operator_tokens, name: "fk_rails_1a807f181b")
    add_foreign_key(
      :operator_tokens, :operator_token_statuses, column: :staff_token_status_id,
                                                  name: "fk_rails_1a807f181b", validate: false, on_delete: :restrict,
    )
  end

  def restore_workflow_references
    remove_foreign_key(:operator_sign_up_flows, name: "fk_rails_fb3acc316b")
    add_foreign_key(
      :operator_sign_up_flows, :operator_sign_up_flow_statuses, column: :status_id,
                                                                name: "fk_rails_fb3acc316b", validate: false,
    )
    remove_foreign_key(:operator_verifications, name: "fk_rails_c8ab8d08df")
    add_foreign_key(
      :operator_verifications, :operator_tokens, column: :staff_token_id,
                                                 name: "fk_rails_c8ab8d08df", validate: false, on_delete: :cascade,
    )
    remove_foreign_key(:operator_auth_admission_bindings, name: "fk_rails_781188228f")
    add_foreign_key(
      :operator_auth_admission_bindings, :operator_auth_ceremony_sessions, column: :auth_ceremony_session_id,
                                                                           name: "fk_rails_781188228f", validate: false, on_delete: :restrict,
    )
    remove_foreign_key(:operator_step_up_sessions, name: "fk_rails_6daa6fb880")
    add_foreign_key(
      :operator_step_up_sessions, :operator_tokens, column: :staff_token_id,
                                                    name: "fk_rails_6daa6fb880", validate: false, on_delete: :cascade,
    )
    remove_foreign_key(:operator_sign_up_flows, name: "fk_rails_10f95a7068")
    add_foreign_key(
      :operator_sign_up_flows, :operator_tokens, column: :token_id,
                                                 name: "fk_rails_10f95a7068", validate: false, on_delete: :cascade,
    )
    remove_foreign_key(:operator_sign_in_flows, name: "fk_rails_0451f7d1d6")
    add_foreign_key(
      :operator_sign_in_flows, :operator_tokens, column: :token_id,
                                                 name: "fk_rails_0451f7d1d6", validate: false, on_delete: :cascade,
    )
  end
end
