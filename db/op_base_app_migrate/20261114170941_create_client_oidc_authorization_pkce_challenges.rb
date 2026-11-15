# frozen_string_literal: true

# PKCE belongs only to Code transactions; front-channel id_token transactions have no row here
# (adr/access-is-a-pure-openid-provider.md, "OP session and transaction storage decisions").
class CreateClientOidcAuthorizationPkceChallenges < ActiveRecord::Migration[8.2]
  def up
    create_table :client_oidc_authorization_pkce_challenges do |t|
      t.references :oidc_authorization_transaction, null: false,
                                                    foreign_key: { to_table: :client_oidc_authorization_transactions,
                                                                   on_delete: :cascade },
                                                    index: { unique: true, name: "idx_client_oidc_pkce_on_transaction" }
      t.string :code_challenge, null: false, limit: 43
      t.string :code_challenge_method, null: false, limit: 8
      t.timestamps
      t.check_constraint "code_challenge_method = 'S256'", name: "chk_client_oidc_pkce_method"
      t.check_constraint "code_challenge ~ '^[A-Za-z0-9_-]{43}$'", name: "chk_client_oidc_pkce_challenge"
    end
  end

  # Runs after the column restore and data copy back. An id_token transaction has no PKCE, so the
  # restore fails while one exists; such rows expire within the transaction lifetime.
  def down
    change_column_null :client_oidc_authorization_transactions, :code_challenge, false
    change_column_null :client_oidc_authorization_transactions, :code_challenge_method, false
    drop_table :client_oidc_authorization_pkce_challenges
  end
end
