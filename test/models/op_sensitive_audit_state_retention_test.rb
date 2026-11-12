# frozen_string_literal: true

require "test_helper"

class OpSensitiveAuditStateRetentionTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "delivery reference states cannot be destroyed while sensitive audit rows depend on them" do
    [[ClientSensitiveAdmissionAuditOutbox, ClientStepUpAuditOutboxDeliveryState, "APP"],
     [OperatorSensitiveAdmissionAuditOutbox, OperatorStepUpAuditOutboxDeliveryState,
      "ORG",],].each do |model, state_model, realm|
      state = state_model.find(state_model::DELIVERED)

      assert_empty state.outboxes
      ref = PublicId.generate
      model.create!(
        event_uuid: SecureRandom.uuid, event_type: "sensitive_admission.closed", realm: realm,
        client_id: "base-#{realm.downcase}-ww", subject_ref: "subject", context_ref: ref,
        reason_code: "completed", payload: { admission_ref: ref }, occurred_at: Time.current,
        delivery_state: state,
      )

      assert_not state.destroy
      assert_predicate state, :persisted?
      assert_raises(ActiveRecord::InvalidForeignKey) do
        state_model.transaction(requires_new: true) { state_model.where(id: state.id).delete_all }
      end
    end
  end
end
