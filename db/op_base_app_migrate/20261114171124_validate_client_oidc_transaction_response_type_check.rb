# frozen_string_literal: true

class ValidateClientOidcTransactionResponseTypeCheck < ActiveRecord::Migration[8.2]
  def change
    validate_check_constraint :client_oidc_authorization_transactions, name: "chk_client_oidc_txns_response_type"
  end
end
