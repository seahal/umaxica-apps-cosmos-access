# frozen_string_literal: true

class AddClientAuthAdmissionBaseTokenIndex < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def up
    add_index :client_auth_admission_bindings, :base_token_id,
              name: "idx_client_auth_admission_bindings_base_token",
              algorithm: :concurrently
  end

  def down
    remove_index :client_auth_admission_bindings,
                 name: "idx_client_auth_admission_bindings_base_token",
                 algorithm: :concurrently
  end
end

