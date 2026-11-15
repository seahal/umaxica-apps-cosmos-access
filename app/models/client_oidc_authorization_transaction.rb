# typed: false
# frozen_string_literal: true

# == Schema Information
#
# Table name: client_oidc_authorization_transactions
# Database name: op_base_app
#
#  id                         :bigint           not null, primary key
#  acr                        :string
#  actor_ref                  :string
#  auth_method                :string
#  authenticated_at           :datetime
#  authorization_grant_redeemed_at :datetime
#  base_finalized_at          :datetime
#  browser_session_ref        :string
#  consumed_at                :datetime
#  expires_at                 :datetime         not null
#  intent                     :string           not null
#  login_challenge            :string           not null
#  login_challenge_expires_at :datetime         not null
#  nonce                      :string           not null
#  redirect_uri               :string           not null
#  result_consumed_at         :datetime
#  result_digest              :string
#  result_expires_at          :datetime
#  result_generation          :integer          default(0), not null
#  response_type              :string           not null
#  scope                      :string           not null
#  session_ref                :string
#  state                      :string           not null
#  status_id                  :bigint           not null
#  surface                    :string           not null
#  created_at                 :datetime         not null
#  updated_at                 :datetime         not null
#  client_id                  :string           not null
#  transaction_id             :string           not null
#
# Indexes
#
#  idx_on_client_id_login_challenge_8f71e56454                     (client_id,login_challenge)
#  idx_on_login_challenge_91d464d261                               (login_challenge) UNIQUE
#  index_client_oidc_authorization_transactions_on_transaction_id  (transaction_id) UNIQUE
#
class ClientOidcAuthorizationTransaction < OpBaseAppRecord
  include OidcAuthorizationTransactionable

  scope :pending, -> { where(status_id: OidcAuthorizationTransactionable::STATUS_PENDING) }
  scope :authenticated, -> { where(status_id: OidcAuthorizationTransactionable::STATUS_AUTHENTICATED) }
  scope :consumed, -> { where(status_id: OidcAuthorizationTransactionable::STATUS_CONSUMED) }
  scope :active_at, ->(time) { where(arel_table[:expires_at].gt(time)) }
  scope :purgeable_at, lambda { |time, retention_period: OidcAuthorizationTransactionable::RETENTION_PERIOD|
    where(arel_table[:expires_at].lteq(time - retention_period))
  }

  validates :transaction_id, :surface, :intent, :client_id, :redirect_uri, :response_type, :scope, :state,
            :nonce, :login_challenge, :login_challenge_expires_at,
            :expires_at, presence: true
  validates :surface, inclusion: { in: %w(app org) }
  validates :intent, inclusion: { in: %w(authentication sign_in sign_up invitation reauthentication step_up) }
  validates :response_type, inclusion: { in: OidcAuthorizationTransactionable::RESPONSE_TYPES }
  validates :oidc_prompt, inclusion: { in: OidcAuthorizationRequestMetadataValue::SUPPORTED_PROMPTS }, allow_nil: true
  validates :oidc_max_age, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validates :status_id, inclusion: { in: OidcAuthorizationTransactionable::STATUS_IDS }
  validates :transaction_id, uniqueness: true
  validates :login_challenge, uniqueness: true
  validate :transaction_surface_matches_class

  has_many :visa_social_link_admissions,
           class_name: "ClientVisaSocialLinkAdmission",
           foreign_key: :oidc_authorization_transaction_id,
           inverse_of: :oidc_authorization_transaction,
           dependent: :restrict_with_error
  has_many :visa_sensitive_admissions,
           class_name: "ClientVisaSensitiveAdmission",
           foreign_key: :oidc_authorization_transaction_id,
           inverse_of: :oidc_authorization_transaction,
           dependent: :restrict_with_error
  has_many :auth_admission_bindings,
           class_name: "ClientAuthAdmissionBinding",
           foreign_key: :authorization_transaction_id,
           inverse_of: :authorization_transaction,
           dependent: :restrict_with_error
  has_many :session_limit_resolution_transactions,
           class_name: "ClientSessionLimitResolutionTransaction",
           foreign_key: :oidc_authorization_transaction_id,
           inverse_of: :oidc_authorization_transaction,
           dependent: :restrict_with_error

  validates :cancellation_handoff_digest, :result_digest, length: { maximum: 64 }
  validates :cancellation_handoff_ref, :cancellation_handoff_digest, uniqueness: true, allow_nil: true
  validates :secret_sign_in_flow_id, uniqueness: true, allow_nil: true

  oidc_authorization_surface "app"

  has_one :pkce_challenge,
          class_name: "ClientOidcAuthorizationPkceChallenge",
          foreign_key: :oidc_authorization_transaction_id,
          inverse_of: :oidc_authorization_transaction,
          dependent: :destroy,
          autosave: true,
          validate: true

  belongs_to :status,
             class_name: "ClientOidcAuthorizationTransactionStatus",
             inverse_of: :client_oidc_authorization_transactions

  belongs_to :secret_sign_in_flow, class_name: "ClientSignInFlow", optional: true
end
