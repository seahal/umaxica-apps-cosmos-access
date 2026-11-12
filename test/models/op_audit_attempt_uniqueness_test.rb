# frozen_string_literal: true

require "test_helper"

class OpAuditAttemptUniquenessTest < ActiveSupport::TestCase
  SOURCES = [
    [ClientStepUpAuditOutbox, ClientStepUpAuditOutboxAttempt, ClientStepUpAuditOutboxDeliveryState,
     "APP", "step_up.requested", "requested",],
    [OperatorStepUpAuditOutbox, OperatorStepUpAuditOutboxAttempt, OperatorStepUpAuditOutboxDeliveryState,
     "ORG", "step_up.requested", "requested",],
    [ClientSensitiveAdmissionAuditOutbox, ClientSensitiveAdmissionAuditAttempt, ClientStepUpAuditOutboxDeliveryState,
     "APP", "sensitive_admission.closed", "completed",],
    [OperatorSensitiveAdmissionAuditOutbox, OperatorSensitiveAdmissionAuditAttempt,
     OperatorStepUpAuditOutboxDeliveryState, "ORG", "sensitive_admission.closed", "completed",],
  ].freeze

  test "ordinary saves preserve per-outbox attempt identity and exactly one delivered result" do
    SOURCES.each do |outbox_model, attempt_model, state_model, realm, event_type, reason_code|
      now = Time.utc(2026, 11, 12, 12)
      outboxes =
        Array.new(2) do
          context_ref = PublicId.generate
          payload =
            case event_type
            when "step_up.requested" then { rp_state_ref: "rp-state", return_target_kind: "relative" }
            when "sensitive_admission.closed" then { admission_ref: context_ref }
            else raise ArgumentError, "unsupported test audit source"
            end
          outbox_model.create!(
            event_uuid: SecureRandom.uuid, event_type: event_type, realm: realm, client_id: "base-#{realm.downcase}-ww",
            subject_ref: "subject", context_ref: context_ref, reason_code: reason_code,
            payload: payload, occurred_at: now,
            delivery_state: state_model.find(state_model::PENDING),
          )
        end
      attributes = { outbox: outboxes.first, attempted_at: now, outcome: "failed", failure_code: "delivery_failed" }
      first = attempt_model.create!(**attributes, attempt_number: 1)
      second = attempt_model.create!(**attributes, attempt_number: 2)
      delivered = attempt_model.create!(**attributes, attempt_number: 3, outcome: "delivered", failure_code: "none")

      [first, second, delivered].each { |record| assert_predicate record, :valid? }
      duplicate_number = attempt_model.new(**attributes, attempt_number: 2)

      assert_not duplicate_number.save
      assert duplicate_number.errors.of_kind?(:attempt_number, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { duplicate_number.save! }

      duplicate_delivery = attempt_model.new(
        **attributes, attempt_number: 4, outcome: "delivered", failure_code: "none",
      )

      assert_not duplicate_delivery.save
      assert duplicate_delivery.errors.of_kind?(:outbox_id, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { duplicate_delivery.save! }
      assert_predicate attempt_model.create!(**attributes, attempt_number: 4), :persisted?
      assert_predicate attempt_model.create!(
        **attributes, outbox: outboxes.last, attempt_number: 1, outcome: "delivered", failure_code: "none",
      ), :persisted?

      [nil, "", 0].each do |number|
        invalid_number = attempt_model.new(**attributes, attempt_number: number)
        invalid_number.validate

        assert invalid_number.errors.of_kind?(:attempt_number, (number == 0) ? :greater_than : :not_a_number)
      end
      assert_equal 1, attempt_model.where(outbox: outboxes.first, outcome: "delivered").count
      assert_equal 3, attempt_model.where(outbox: outboxes.first, outcome: "failed").count
    end
  end

  test "PostgreSQL retains ordinal and partial-delivery uniqueness with required outbox references" do
    SOURCES.each do |outbox_model, attempt_model, state_model, realm, event_type, reason_code|
      now = Time.utc(2026, 11, 12, 12)
      context_ref = PublicId.generate
      payload =
        case event_type
        when "step_up.requested" then { rp_state_ref: "rp-state", return_target_kind: "relative" }
        when "sensitive_admission.closed" then { admission_ref: context_ref }
        else raise ArgumentError, "unsupported test audit source"
        end
      outbox = outbox_model.create!(
        event_uuid: SecureRandom.uuid, event_type: event_type, realm: realm, client_id: "base-#{realm.downcase}-ww",
        subject_ref: "subject", context_ref: context_ref, reason_code: reason_code, payload: payload, occurred_at: now,
        delivery_state: state_model.find(state_model::PENDING),
      )
      attributes = { outbox_id: outbox.id, attempted_at: now, outcome: "failed", failure_code: "delivery_failed" }
      attempt_model.insert_all!([{ **attributes, attempt_number: 1 }])

      assert_raises(ActiveRecord::RecordNotUnique) do
        attempt_model.transaction(requires_new: true) {
          attempt_model.insert_all!([{ **attributes, attempt_number: 1 }])
        }
      end
      attempt_model.insert_all!([{ **attributes, attempt_number: 2, outcome: "delivered", failure_code: "none" }])

      assert_raises(ActiveRecord::RecordNotUnique) do
        attempt_model.transaction(requires_new: true) do
          attempt_model.insert_all!([{ **attributes, attempt_number: 3, outcome: "delivered", failure_code: "none" }])
        end
      end
      attempt_model.insert_all!([{ **attributes, attempt_number: 3 }])
      error =
        assert_raises(ActiveRecord::StatementInvalid) do
          attempt_model.transaction(requires_new: true) {
            attempt_model.insert_all!([{ **attributes, attempt_number: 0 }])
          }
        end

      assert_instance_of PG::CheckViolation, error.cause
      assert_raises(ActiveRecord::NotNullViolation) do
        attempt_model.transaction(requires_new: true) do
          attempt_model.insert_all!([{ **attributes, attempt_number: nil }])
        end
      end
      assert_raises(ActiveRecord::NotNullViolation) do
        attempt_model.transaction(requires_new: true) do
          attempt_model.insert_all!([{ **attributes, attempt_number: 4, outbox_id: nil }])
        end
      end
      assert_raises(ActiveRecord::InvalidForeignKey) do
        attempt_model.transaction(requires_new: true) do
          attempt_model.insert_all!([{ **attributes, attempt_number: 4, outbox_id: -1 }])
        end
      end
      assert_equal 3, attempt_model.where(outbox_id: outbox.id).count
    end
  end
end
