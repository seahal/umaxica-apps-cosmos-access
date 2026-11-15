# frozen_string_literal: true

class RemoveOperatorOidcAuthorizationTransactionPkceColumns < ActiveRecord::Migration[8.2]
  def up
    safety_assured do
      remove_column :operator_oidc_authorization_transactions, :code_challenge
      remove_column :operator_oidc_authorization_transactions, :code_challenge_method
    end
    add_check_constraint :operator_oidc_authorization_transactions, "response_type IN ('code', 'id_token')",
                         name: "chk_operator_oidc_txns_response_type", validate: false
  end

  # Restores the columns; the preceding data step copies values back before NOT NULL applies.
  def down
    remove_check_constraint :operator_oidc_authorization_transactions, name: "chk_operator_oidc_txns_response_type"
    add_column :operator_oidc_authorization_transactions, :code_challenge, :string
    add_column :operator_oidc_authorization_transactions, :code_challenge_method, :string
  end
end
