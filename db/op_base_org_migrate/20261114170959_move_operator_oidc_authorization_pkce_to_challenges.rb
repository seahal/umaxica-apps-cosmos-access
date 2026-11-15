# frozen_string_literal: true

# Data step between the child-table creation and the column removal (owner decision 2026-11-15).
# Transactions live at most 15 minutes plus retention, so only in-flight Code rows are copied.
class MoveOperatorOidcAuthorizationPkceToChallenges < ActiveRecord::Migration[8.2]
  class AuthorizationTransaction < ActiveRecord::Base
    self.table_name = "operator_oidc_authorization_transactions"
  end

  class PkceChallenge < ActiveRecord::Base
    self.table_name = "operator_oidc_authorization_pkce_challenges"
  end

  def up
    AuthorizationTransaction.where(response_type: "code").find_each do |row|
      PkceChallenge.create!(
        oidc_authorization_transaction_id: row.id,
        code_challenge: row.code_challenge,
        code_challenge_method: row.code_challenge_method,
      )
    end
  end

  def down
    PkceChallenge.find_each do |row|
      AuthorizationTransaction.where(id: row.oidc_authorization_transaction_id).update_all(
        code_challenge: row.code_challenge, code_challenge_method: row.code_challenge_method,
      )
    end
  end
end
