# typed: false
# frozen_string_literal: true

# Acme/app durable one-shot storage for social link ceremony results.
# == Schema Information
#
# Table name: client_social_ceremony_transactions
# Database name: op_base_app
#
#  id                      :bigint           not null, primary key
#  actor_ref               :string           not null
#  consumed_at             :datetime
#  expires_at              :datetime         not null
#  grant_jti               :string           not null
#  lock_version            :bigint           default(0), not null
#  operation               :string           not null
#  provider                :string           not null
#  provider_subject_digest :string
#  provider_subject_ref    :string
#  resource_ref            :string
#  result_jti              :string
#  return_to               :string
#  session_ref             :string           not null
#  status                  :string           default("pending"), not null
#  surface                 :string           not null
#  created_at              :datetime         not null
#  updated_at              :datetime         not null
#  transaction_id          :string           not null
#
# Indexes
#
#  idx_on_actor_ref_session_ref_b5b014c24f                      (actor_ref,session_ref)
#  idx_on_provider_provider_subject_digest_8b462593cd           (provider,provider_subject_digest)
#  index_client_social_ceremony_transactions_on_expires_at      (expires_at)
#  index_client_social_ceremony_transactions_on_grant_jti       (grant_jti) UNIQUE
#  index_client_social_ceremony_transactions_on_result_jti      (result_jti) UNIQUE WHERE (result_jti IS NOT NULL)
#  index_client_social_ceremony_transactions_on_transaction_id  (transaction_id) UNIQUE
#
class ClientSocialCeremonyTransaction < OpBaseAppRecord
  has_many :visa_social_link_admissions,
           class_name: "ClientVisaSocialLinkAdmission",
           foreign_key: :social_ceremony_transaction_id,
           inverse_of: :social_ceremony_transaction,
           dependent: :restrict_with_error

  include SocialCeremonyTransactionable

  scope :expired_at, ->(time) { where(arel_table[:expires_at].lteq(time)) }
  scope :consumed, -> { where.not(consumed_at: nil).or(where(status: SocialCeremonyTransactionable::STATUS_CONSUMED)) }
  scope :active_at, ->(time) {
    where(arel_table[:expires_at].gt(time)).where(consumed_at: nil, status: SocialCeremonyTransactionable::STATUS_PENDING)
  }
  scope :pending, -> { where(status: SocialCeremonyTransactionable::STATUS_PENDING, consumed_at: nil) }
  scope :purgeable_at, lambda { |time, retention_period: SocialCeremonyTransactionable::RETENTION_PERIOD|
    cutoff = time - retention_period
    where(arel_table[:expires_at].lteq(cutoff))
      .or(where(arel_table[:consumed_at].lteq(cutoff)))
  }

  validates :transaction_id, :surface, :actor_ref, :session_ref, :operation, :provider, :status, :grant_jti,
            :expires_at, presence: true
  validates :transaction_id, uniqueness: true
  validates :grant_jti, uniqueness: true
  validates :result_jti, uniqueness: true, allow_nil: true
  validates :surface, inclusion: { in: IdentitySocialCeremonyContract::SURFACES }
  validates :operation, inclusion: { in: IdentitySocialCeremonyContract::OPERATIONS }
  validates :provider, inclusion: { in: IdentitySocialCeremonyContract::PROVIDERS }
  validates :status, inclusion: { in: SocialCeremonyTransactionable::STATUSES }
  validate :surface_matches_transaction_class
  validate :consumed_transaction_has_result

  ceremony_surface "app"
end
