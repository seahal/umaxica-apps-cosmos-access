# frozen_string_literal: true

class ValidateOperatorOidcTransactionResponseTypeCheck < ActiveRecord::Migration[8.2]
  def change
    validate_check_constraint :operator_oidc_authorization_transactions, name: "chk_operator_oidc_txns_response_type"
  end
end
