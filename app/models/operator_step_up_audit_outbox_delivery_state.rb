# frozen_string_literal: true

class OperatorStepUpAuditOutboxDeliveryState < OpBaseOrgRecord
  include ReferenceRecord

  self.record_timestamps = false

  PENDING = 10
  DELIVERED = 20
  DEFAULTS = [PENDING, DELIVERED].freeze

  has_many :outboxes,
           class_name: "OperatorStepUpAuditOutbox",
           foreign_key: :delivery_state_id,
           inverse_of: :delivery_state,
           dependent: :restrict_with_error
  has_many :sensitive_admission_outboxes,
           class_name: "OperatorSensitiveAdmissionAuditOutbox",
           foreign_key: :delivery_state_id,
           inverse_of: :delivery_state,
           dependent: :restrict_with_error
end
