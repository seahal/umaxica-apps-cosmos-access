# typed: false
# frozen_string_literal: true

# Acme/org durable one-shot storage for email ceremony results.
# == Schema Information
#
# Table name: operator_email_ceremony_transactions
# Database name: op_base_org
#
#  id                      :bigint           not null, primary key
#  actor_ref               :string           not null
#  consumed_at             :datetime
#  email_candidate_ref     :string
#  expires_at              :datetime         not null
#  grant_jti               :string           not null
#  lock_version            :bigint           default(0), not null
#  normalized_email_digest :string
#  operation               :string           not null
#  result_jti              :string
#  session_ref             :string           not null
#  status                  :string           default("pending"), not null
#  surface                 :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  transaction_id          :string           not null
#
# Indexes
#
#  idx_on_actor_ref_session_ref_2ccab820e8                       (actor_ref,session_ref)
#  index_operator_email_ceremony_transactions_on_expires_at      (expires_at)
#  index_operator_email_ceremony_transactions_on_grant_jti       (grant_jti) UNIQUE
#  index_operator_email_ceremony_transactions_on_result_jti      (result_jti) UNIQUE WHERE (result_jti IS NOT NULL)
#  index_operator_email_ceremony_transactions_on_transaction_id  (transaction_id) UNIQUE
#
class OperatorEmailCeremonyTransaction < OpBaseOrgRecord
  include EmailCeremonyTransactionable

  validates :evp_outcome, inclusion: { in: EmailVerificationChallengeable::OUTCOMES }, allow_nil: true
  validates :evp_failure_reason, inclusion: { in: EmailVerificationChallengeable::FAILURE_REASONS }, allow_nil: true
  validates :evp_attempt_count, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validate :evp_challenge_metadata_is_consistent
  scope :expired_at, ->(time) { where(arel_table[:expires_at].lteq(time)) }
  scope :consumed, -> { where.not(consumed_at: nil).or(where(status: EmailCeremonyTransactionable::STATUS_CONSUMED)) }
  scope :active_at, ->(time) {
    where(arel_table[:expires_at].gt(time)).where(consumed_at: nil, status: EmailCeremonyTransactionable::STATUS_PENDING)
  }
  scope :pending, -> { where(status: EmailCeremonyTransactionable::STATUS_PENDING, consumed_at: nil) }
  scope :purgeable_at, lambda { |time, retention_period: EmailCeremonyTransactionable::RETENTION_PERIOD|
    cutoff = time - retention_period
    where(arel_table[:expires_at].lteq(cutoff))
      .or(where(arel_table[:consumed_at].lteq(cutoff)))
  }

  validates :transaction_id, :surface, :actor_ref, :session_ref, :operation, :status, :grant_jti, :expires_at,
            presence: true
  validates :transaction_id, uniqueness: true
  validates :grant_jti, uniqueness: true
  validates :result_jti, uniqueness: true, allow_nil: true
  validates :surface, inclusion: { in: IdentityEmailCeremonyContract::SURFACES }
  validates :operation, inclusion: { in: EmailCeremonyTransactionable::OPERATIONS }
  validates :status, inclusion: { in: EmailCeremonyTransactionable::STATUSES }
  validate :surface_matches_transaction_class
  validate :consumed_transaction_has_result
  include EmailCeremonyOtp

  validates :evp_nonce_digest, :evp_token_digest, uniqueness: true, allow_nil: true

  validate :immutable_email_otp_terminal_facts

  ceremony_surface "org"
end
