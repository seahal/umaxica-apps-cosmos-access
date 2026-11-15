# typed: false
# frozen_string_literal: true

# Acme/app durable one-shot storage for passkey ceremony results.
# == Schema Information
#
# Table name: client_passkey_ceremony_transactions
# Database name: op_base_app
#
#  id                          :bigint           not null, primary key
#  actor_ref                   :string           not null
#  consumed_at                 :datetime
#  credential_candidate_digest :string
#  credential_candidate_ref    :string
#  expires_at                  :datetime         not null
#  grant_jti                   :string           not null
#  lock_version                :bigint           default(0), not null
#  operation                   :string           not null
#  origin                      :string           not null
#  result_jti                  :string
#  session_ref                 :string           not null
#  status                      :string           default("pending"), not null
#  surface                     :string           not null
#  created_at                  :datetime         not null
#  updated_at                  :datetime         not null
#  rp_id                       :string           not null
#  transaction_id              :string           not null
#
# Indexes
#
#  idx_on_actor_ref_session_ref_334fbe1b51                       (actor_ref,session_ref)
#  index_client_passkey_ceremony_transactions_on_expires_at      (expires_at)
#  index_client_passkey_ceremony_transactions_on_grant_jti       (grant_jti) UNIQUE
#  index_client_passkey_ceremony_transactions_on_result_jti      (result_jti) UNIQUE WHERE (result_jti IS NOT NULL)
#  index_client_passkey_ceremony_transactions_on_transaction_id  (transaction_id) UNIQUE
#
class ClientPasskeyCeremonyTransaction < OpBaseAppRecord
  include PasskeyCeremonyTransactionable

  scope :expired_at, ->(time) { where(arel_table[:expires_at].lteq(time)) }
  scope :consumed, -> { where.not(consumed_at: nil).or(where(status: PasskeyCeremonyTransactionable::STATUS_CONSUMED)) }
  scope :active_at, ->(time) {
    where(arel_table[:expires_at].gt(time)).where(consumed_at: nil, status: PasskeyCeremonyTransactionable::STATUS_PENDING)
  }
  scope :pending, -> { where(status: PasskeyCeremonyTransactionable::STATUS_PENDING, consumed_at: nil) }
  scope :purgeable_at, lambda { |time, retention_period: PasskeyCeremonyTransactionable::RETENTION_PERIOD|
    cutoff = time - retention_period
    where(arel_table[:expires_at].lteq(cutoff))
      .or(where(arel_table[:consumed_at].lteq(cutoff)))
  }

  validates :transaction_id, :surface, :actor_ref, :session_ref, :operation, :status, :grant_jti, :expires_at,
            :rp_id, :origin,
            presence: true
  validates :transaction_id, uniqueness: true
  validates :grant_jti, uniqueness: true
  validates :result_jti, uniqueness: true, allow_nil: true
  validates :surface, inclusion: { in: IdentityPasskeyCeremonyContract::SURFACES }
  validates :operation, inclusion: { in: IdentityPasskeyCeremonyContract::OPERATIONS }
  validates :status, inclusion: { in: PasskeyCeremonyTransactionable::STATUSES }
  validate :surface_matches_transaction_class
  validate :consumed_transaction_has_result

  ceremony_surface "app"
end
