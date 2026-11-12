# frozen_string_literal: true

class AddOpAppLifecycleStatusIndexes < ActiveRecord::Migration[8.2]
  disable_ddl_transaction!

  def change
    # Full indexes support every state lookup and restrictive reference-table deletion check.
    # Existing partial indexes enforce active admission/ceremony uniqueness and remain separate.
    add_index(:client_auth_admission_bindings, :status_id, algorithm: :concurrently)
    add_index(:client_auth_ceremony_sessions, :status_id, algorithm: :concurrently)
    add_index(:client_oidc_authorization_transactions, :status_id, algorithm: :concurrently)
  end
end
