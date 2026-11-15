# frozen_string_literal: true

class RemoveClientOidcAuthorizationTransactionPkceColumns < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      remove_column :client_oidc_authorization_transactions, :code_challenge
      remove_column :client_oidc_authorization_transactions, :code_challenge_method
    end
    add_check_constraint :client_oidc_authorization_transactions, "response_type IN ('code', 'id_token')",
                         name: "chk_client_oidc_txns_response_type", validate: false
  end

  # Restores the columns; the preceding data step copies values back before NOT NULL applies.
  def down
    remove_check_constraint :client_oidc_authorization_transactions, name: "chk_client_oidc_txns_response_type"
    add_column :client_oidc_authorization_transactions, :code_challenge, :string
    add_column :client_oidc_authorization_transactions, :code_challenge_method, :string
  end
end
