# frozen_string_literal: true

require "test_helper"

class OpStepUpHandoffUniquenessTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "verified result digests are unique across ceremony transactions in each realm" do
    [ClientStepUpCeremonyTransaction, OperatorStepUpCeremonyTransaction].each do |model|
      rows =
        2.times.map do
          row = model.create_transaction!(
            actor_ref: "actor", session_ref: "session", required_scope: "settings_passkey",
            allowed_methods: ["passkey"],
          )
          row.record_verification!(
            method: "passkey", aal: "aal1", phishing_resistant: true, user_verified: false,
            verified_at: model.database_now, verified_credential_ref: "credential",
          )
          row
        end
      digest = SecureRandom.hex(32)
      rows.first.prepare_result_delivery!(result_digest: digest, ttl: 60.seconds)
      rows.last.assign_attributes(result_digest: digest, result_generation: 1, result_expires_at: 30.seconds.from_now)

      assert_not rows.last.valid?
      assert rows.last.errors.of_kind?(:result_digest, :taken)
      assert_raises(ActiveRecord::RecordNotUnique) do
        model.transaction(requires_new: true) do
          rows.last.update_columns(result_digest: digest, result_generation: 1, result_expires_at: 30.seconds.from_now)
        end
      end
    end
  end

  test "cancellation references and digests remain unique without blocking absent values" do
    [ClientStepUpCeremonyTransaction, OperatorStepUpCeremonyTransaction].each do |model|
      [:cancellation_handoff_ref, :cancellation_handoff_digest].each do |field|
        rows =
          2.times.map do
            model.create_transaction!(
              actor_ref: "actor", session_ref: "session", required_scope: "settings_passkey",
              allowed_methods: ["passkey"],
            )
          end
        value = (field == :cancellation_handoff_ref) ? SecureRandom.uuid : SecureRandom.hex(32)
        attributes = { field => value }
        attributes[:cancellation_handoff_ciphertext] = "ciphertext" if field == :cancellation_handoff_ref
        rows.first.update_columns(attributes)
        rows.last.assign_attributes(attributes)

        assert_not rows.last.valid?
        assert rows.last.errors.of_kind?(field, :taken)
        assert_raises(ActiveRecord::RecordNotUnique) do
          model.transaction(requires_new: true) { rows.last.update_columns(attributes) }
        end
      end
    end
  end
end
