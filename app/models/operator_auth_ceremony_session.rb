# typed: false
# frozen_string_literal: true

class OperatorAuthCeremonySession < OpBaseOrgRecord
  include AuthCeremonySession

  has_many :auth_admission_bindings,
           class_name: "OperatorAuthAdmissionBinding",
           foreign_key: :auth_ceremony_session_id,
           inverse_of: :auth_ceremony_session,
           dependent: :restrict_with_error

  belongs_to :status,
             class_name: "OperatorAuthCeremonySessionStatus",
             inverse_of: :operator_auth_ceremony_sessions

  validates :sid_digest, presence: true, uniqueness: true, length: { is: 64 }
  validates :authorization_transaction_ref,
            uniqueness: {
              conditions: -> {
                where.not(authorization_transaction_ref: nil)
                  .where.not(status_id: AuthCeremonySession::CANCELLED_STATUS_IDS)
              },
            },
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
