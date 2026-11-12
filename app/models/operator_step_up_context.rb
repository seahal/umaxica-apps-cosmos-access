# frozen_string_literal: true

class OperatorStepUpContext < OpBaseOrgRecord
  belongs_to :oidc_authorization_transaction, class_name: "OperatorOidcAuthorizationTransaction"
  belongs_to :grant, class_name: "OpOrgGrant"
  belongs_to :state, class_name: "OperatorStepUpContextState", inverse_of: :contexts

  has_many :transitions,
           class_name: "OperatorStepUpContextTransition",
           foreign_key: :owner_id,
           inverse_of: :owner,
           dependent: :delete_all

  validates :public_id, :bound_subject, :requested_acr, :expires_at, presence: true
  validates :public_id, length: { is: 21 }
  validates :public_id, :oidc_authorization_transaction_id, uniqueness: true
  validates :bound_subject, :requested_acr, length: { maximum: 255 }
end
