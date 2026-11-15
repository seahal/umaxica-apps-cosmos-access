# typed: false
# frozen_string_literal: true

# Acme/app durable one-shot storage for step-up ceremony results.
# == Schema Information
#
# Table name: client_step_up_ceremony_transactions
# Database name: op_base_app
#
#  id              :bigint           not null, primary key
#  aal             :string           # @deprecated evidence label; remove after explicit-evidence consumers migrate
#  actor_ref       :string           not null
#  allowed_methods :text             not null
#  consumed_at     :datetime
#  expires_at      :datetime         not null
#  grant_jti       :string           not null
#  lock_version    :bigint           default(0), not null
#  method          :string
#  required_aal    :string           not null        # @deprecated label; remove after AAL ledger retirement
#  required_scope  :string           not null
#  step_up_required :boolean         not null
#  user_verification_required :boolean not null
#  full_reauthentication_required :boolean not null
#  audience        :string
#  token_binding   :string
#  require_session_binding :boolean  not null
#  tenant_ref      :string
#  resource_ref    :string
#  result_jti      :string
#  return_to       :string
#  session_ref     :string           not null
#  status          :string           default("pending"), not null
#  surface         :string           not null
#  verified_at     :datetime
#  user_verified   :boolean          default(FALSE), not null
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  transaction_id  :string           not null
#
# Indexes
#
#  idx_on_actor_ref_session_ref_4f24c7001d                       (actor_ref,session_ref)
#  index_client_step_up_ceremony_transactions_on_expires_at      (expires_at)
#  index_client_step_up_ceremony_transactions_on_grant_jti       (grant_jti) UNIQUE
#  index_client_step_up_ceremony_transactions_on_required_scope  (required_scope)
#  index_client_step_up_ceremony_transactions_on_result_jti      (result_jti) UNIQUE WHERE (result_jti IS NOT NULL)
#  index_client_step_up_ceremony_transactions_on_transaction_id  (transaction_id) UNIQUE
#
class ClientStepUpCeremonyTransaction < OpBaseAppRecord
  include StepUpCeremonyTransactionable

  scope :expired_at, ->(time) { where(arel_table[:expires_at].lteq(time)) }
  scope :consumed, -> { where.not(consumed_at: nil).or(where(status: StepUpCeremonyTransactionable::STATUS_CONSUMED)) }
  scope :canceled, -> { where(status: StepUpCeremonyTransactionable::STATUS_CANCELED) }
  scope :active_at, ->(time) {
    where(arel_table[:expires_at].gt(time)).where(consumed_at: nil, status: StepUpCeremonyTransactionable::STATUS_PENDING)
  }
  scope :pending, -> { where(status: StepUpCeremonyTransactionable::STATUS_PENDING, consumed_at: nil) }
  scope :purgeable_at, lambda { |time, retention_period: StepUpCeremonyTransactionable::RETENTION_PERIOD|
    cutoff = time - retention_period
    where(arel_table[:expires_at].lteq(cutoff))
      .or(where(arel_table[:consumed_at].lteq(cutoff)))
  }

  validates :transaction_id, :surface, :actor_ref, :session_ref, :required_scope, :required_aal, :status,
            :grant_jti, :expires_at, presence: true
  validates :transaction_id, uniqueness: true
  validates :grant_jti, uniqueness: true
  validates :result_jti, uniqueness: true, allow_nil: true
  validates :allowed_methods, presence: true
  validates :surface, inclusion: { in: IdentityStepUpCeremonyContract::SURFACES }
  # @deprecated `required_aal` is a storage label only; remove it after the AAL removal ledger
  # has retired historical rows and signed compatibility fixtures.
  validates :required_aal, inclusion: { in: IdentityStepUpCeremonyContract::AALS }
  validates :aal, inclusion: { in: IdentityStepUpCeremonyContract::AALS }, allow_blank: true
  validates :method, inclusion: { in: IdentityStepUpCeremonyContract::METHODS }, allow_blank: true
  validates :status, inclusion: { in: StepUpCeremonyTransactionable::STATUSES }
  validates :step_up_required, :user_verification_required, :full_reauthentication_required,
            :phishing_resistant_required,
            :require_session_binding, inclusion: { in: [true, false] }
  validates :audience, :token_binding, presence: true
  validate :surface_matches_transaction_class
  validate :allowed_methods_are_valid
  validate :consumed_transaction_has_result
  validate :cancellation_handoff_fields_are_consistent

  has_many :visa_social_link_admissions,
           class_name: "ClientVisaSocialLinkAdmission",
           foreign_key: :step_up_ceremony_transaction_id,
           inverse_of: :step_up_ceremony_transaction,
           dependent: :restrict_with_error
  has_many :visa_sensitive_admissions,
           class_name: "ClientVisaSensitiveAdmission",
           foreign_key: :step_up_ceremony_transaction_id,
           inverse_of: :step_up_ceremony_transaction,
           dependent: :restrict_with_error
  has_many :auth_admission_bindings,
           class_name: "ClientAuthAdmissionBinding",
           foreign_key: :step_up_ceremony_transaction_id,
           inverse_of: :step_up_ceremony_transaction,
           dependent: :restrict_with_error

  ceremony_surface "app"

  belongs_to :evidence_state, class_name: "ClientStepUpEvidenceState", inverse_of: :ceremony_transactions
  validates :evidence_state_id, inclusion: { in: IdentityStepUpCeremonyContract::EVIDENCE_STATES }
  validates :user_verified, inclusion: { in: [true, false] }
  validate :evidence_state_matches_verification

  validates :cancellation_handoff_digest, :result_digest, length: { maximum: 64 }
  validates :cancellation_handoff_ref, :cancellation_handoff_digest, :result_digest, uniqueness: true, allow_nil: true

  private

  def permitted_ceremony_methods = %w(passkey totp email_otp)
end
