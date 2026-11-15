# typed: false
# frozen_string_literal: true

# PKCE S256 binding of a Code authorization transaction. A front-channel id_token transaction has
# none (adr/access-is-a-pure-openid-provider.md, "OP session and transaction storage decisions").
class OperatorOidcAuthorizationPkceChallenge < OpBaseOrgRecord
  belongs_to :oidc_authorization_transaction,
             class_name: "OperatorOidcAuthorizationTransaction",
             inverse_of: :pkce_challenge

  validates :code_challenge, format: { with: OidcAuthorizeRequestResolver::CODE_CHALLENGE_PATTERN }
  validates :code_challenge_method, inclusion: { in: ["S256"] }
  validates :oidc_authorization_transaction_id, uniqueness: true
end
