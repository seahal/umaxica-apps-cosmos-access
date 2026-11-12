# typed: false
# frozen_string_literal: true

class OperatorAuthCeremonySession < OpBaseOrgRecord
  include AuthCeremonySession

  belongs_to :status,
             class_name: "OperatorAuthCeremonySessionStatus",
             inverse_of: :operator_auth_ceremony_sessions

  validates :sid_digest, presence: true, uniqueness: true, length: { is: 64 }
  validates :authorization_transaction_ref,
            uniqueness: { conditions: -> { where.not(status_id: AuthCeremonySession::CANCELLED_STATUS_IDS) } },
            allow_nil: true, if: -> { AuthCeremonySession::CANCELLED_STATUS_IDS.exclude?(status_id) }
  validates :expires_at, presence: true
  validates :status_id, inclusion: { in: AuthCeremonySession::STATUS_IDS }
  validates :previous_sid_digest, length: { maximum: 64 }

  before_validation :normalize_blank_previous_digest

  private

  def normalize_blank_previous_digest
    self.previous_sid_digest = previous_sid_digest.presence
  end
end
