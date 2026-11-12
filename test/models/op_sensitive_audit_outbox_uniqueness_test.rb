# frozen_string_literal: true

require "test_helper"

class OpSensitiveAuditOutboxUniquenessTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "each realm rejects repeated event UUIDs and admission references" do
    [[ClientSensitiveAdmissionAuditOutbox, ClientStepUpAuditOutboxDeliveryState, "APP"],
     [OperatorSensitiveAdmissionAuditOutbox, OperatorStepUpAuditOutboxDeliveryState,
      "ORG",],].each do |model, state, realm|
      ref = PublicId.generate
      attributes = {
        event_uuid: SecureRandom.uuid,
        event_type: "sensitive_admission.closed",
        realm: realm,
        client_id: "base-#{realm.downcase}-ww",
        subject_ref: "subject",
        context_ref: ref,
        reason_code: "completed",
        payload: { admission_ref: ref },
        occurred_at: Time.current,
        delivery_state: state.find(state::PENDING),
      }
      model.create!(**attributes)
      other_ref = PublicId.generate
      duplicate_uuid = model.new(**attributes.merge(context_ref: other_ref, payload: { admission_ref: other_ref }))
      duplicate_ref = model.new(**attributes.merge(event_uuid: SecureRandom.uuid))

      assert_not duplicate_uuid.valid?
      assert duplicate_uuid.errors.of_kind?(:event_uuid, :taken)
      assert_not duplicate_ref.valid?
      assert duplicate_ref.errors.of_kind?(:context_ref, :taken)
      [duplicate_uuid, duplicate_ref].each do |duplicate|
        assert_raises(ActiveRecord::RecordNotUnique) do
          model.transaction(requires_new: true) { duplicate.save!(validate: false) }
        end
      end
    end
  end
end
