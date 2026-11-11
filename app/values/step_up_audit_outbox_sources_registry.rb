# frozen_string_literal: true

class StepUpAuditOutboxSourcesRegistry
  SOURCES = {
    "o9_app" => [ClientSensitiveAdmissionAuditOutbox, "APP", ClientSensitiveAdmissionAuditAttempt,
                 ClientStepUpAuditOutboxDeliveryState::PENDING, ClientStepUpAuditOutboxDeliveryState::DELIVERED,].freeze,
    "o9_org" => [OperatorSensitiveAdmissionAuditOutbox, "ORG", OperatorSensitiveAdmissionAuditAttempt,
                 OperatorStepUpAuditOutboxDeliveryState::PENDING, OperatorStepUpAuditOutboxDeliveryState::DELIVERED,].freeze,
    "op_app" => [
      ClientStepUpAuditOutbox,
      "APP",
      ClientStepUpAuditOutboxAttempt,
      ClientStepUpAuditOutboxDeliveryState::PENDING,
      ClientStepUpAuditOutboxDeliveryState::DELIVERED,
    ].freeze,
    "op_org" => [
      OperatorStepUpAuditOutbox,
      "ORG",
      OperatorStepUpAuditOutboxAttempt,
      OperatorStepUpAuditOutboxDeliveryState::PENDING,
      OperatorStepUpAuditOutboxDeliveryState::DELIVERED,
    ].freeze,
  }.freeze
end
