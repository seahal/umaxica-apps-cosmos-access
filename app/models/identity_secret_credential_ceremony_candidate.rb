# typed: false
# frozen_string_literal: true

class IdentitySecretCredentialCeremonyCandidate < OpBaseAppRecord
  include IdentityCeremonyCandidateRecord

  scope :active_at, ->(time) { where(arel_table[:expires_at].gt(time), consumed_at: nil) }

  validates :ref, :digest, :surface, :actor_ref, :session_ref, :expires_at, presence: true
  validates :ref, uniqueness: true

  encrypts :password_digest

  validates :transaction_id, :operation, :password_digest, presence: true
  validates :enabled, inclusion: { in: [true, false] }
  validates :surface, inclusion: { in: IdentitySecretCredentialCeremonyContract::SURFACES }
  validates :operation, inclusion: { in: IdentitySecretCredentialCeremonyContract::OPERATIONS }
  validates :name, exclusion: { in: [nil] }
end
