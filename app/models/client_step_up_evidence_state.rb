# frozen_string_literal: true

class ClientStepUpEvidenceState < OpBaseAppRecord
  include ReferenceRecord

  ABSENT = IdentityStepUpCeremonyContract::EVIDENCE_ABSENT
  RECORDED = IdentityStepUpCeremonyContract::EVIDENCE_RECORDED
  DEFAULTS = [ABSENT, RECORDED].freeze

  has_many :tokens, class_name: "ClientToken", foreign_key: :evidence_state_id,
                    inverse_of: :evidence_state, dependent: :restrict_with_exception
  has_many :ceremony_transactions, class_name: "ClientStepUpCeremonyTransaction", foreign_key: :evidence_state_id,
                                   inverse_of: :evidence_state, dependent: :restrict_with_exception

  validates :id, inclusion: { in: DEFAULTS }
end
