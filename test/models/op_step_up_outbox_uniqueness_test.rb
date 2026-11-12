# frozen_string_literal: true

require "test_helper"

class OpStepUpOutboxUniquenessTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "event UUID and rejected attempt identity follow their database unique indexes" do
    [[ClientStepUpAuditOutbox, ClientStepUpAuditOutboxDeliveryState, "APP"],
     [OperatorStepUpAuditOutbox, OperatorStepUpAuditOutboxDeliveryState, "ORG"],].each do |model, state, realm|
      attrs = {
        event_uuid: SecureRandom.uuid,
        event_type: "step_up.attempt_rejected",
        realm: realm,
        client_id: "base-#{realm.downcase}-ww",
        subject_ref: "subject",
        context_ref: PublicId.generate,
        reason_code: "foreign_browser",
        payload: { context_ref: "context", rejection_code: "foreign_browser" },
        occurred_at: Time.current,
        delivery_state: state.find(state::PENDING),
      }
      model.create!(**attrs)
      duplicate_uuid = model.new(**attrs.merge(context_ref: PublicId.generate))
      duplicate_identity = model.new(**attrs.merge(event_uuid: SecureRandom.uuid))

      assert_not duplicate_uuid.valid?
      assert duplicate_uuid.errors.of_kind?(:event_uuid, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { duplicate_uuid.save! }
      assert_not duplicate_identity.valid?
      assert duplicate_identity.errors.of_kind?(:context_ref, :taken)
      assert_raises(ActiveRecord::RecordNotUnique) do
        model.transaction(requires_new: true) { duplicate_identity.save!(validate: false) }
      end
      requested = model.new(
        **attrs.merge(
          event_uuid: SecureRandom.uuid, event_type: "step_up.requested", reason_code: "requested",
          payload: { rp_state_ref: "rp-state", return_target_kind: "relative" },
        ),
      )

      assert_predicate requested, :valid?
      assert_predicate requested.save!, :itself
    end
  end
end
