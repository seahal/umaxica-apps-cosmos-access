# typed: false
# frozen_string_literal: true

class IdentityTotpCeremonyCandidate < OpBaseAppRecord
  include IdentityCeremonyCandidateRecord

  scope :active_at, ->(time) { where(arel_table[:expires_at].gt(time), consumed_at: nil) }

  validates :ref, :digest, :surface, :actor_ref, :session_ref, :expires_at, presence: true
  validates :ref, uniqueness: true

  encrypts :private_key

  validates :private_key, presence: true
  validates :last_otp_at, presence: true, if: :unbound_candidate?
  validates :surface, inclusion: { in: IdentityTotpCeremonyContract::SURFACES }

  private

  def unbound_candidate? = step_up_ceremony_transaction_ref.nil?
end
