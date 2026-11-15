# frozen_string_literal: true

class AddOperatorSessionLimitForeignKeyIndexes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    add_index :operator_session_limit_resolution_transactions, :oidc_authorization_transaction_id,
              name: "idx_operator_session_limit_oidc_transaction",
              algorithm: :concurrently
    add_index :operator_auth_admission_bindings, :base_token_id,
              name: "idx_operator_auth_admission_bindings_base_token",
              algorithm: :concurrently
  end

  def down
    remove_index :operator_session_limit_resolution_transactions,
                 name: "idx_operator_session_limit_oidc_transaction",
                 algorithm: :concurrently
    remove_index :operator_auth_admission_bindings,
                 name: "idx_operator_auth_admission_bindings_base_token",
                 algorithm: :concurrently
  end
end

