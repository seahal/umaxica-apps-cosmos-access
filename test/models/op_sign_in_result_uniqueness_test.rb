# frozen_string_literal: true

require "test_helper"

class OpSignInResultUniquenessTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "operator signup history keeps result digests unique" do
    OperatorSignUpFlowStatus.ensure_defaults!
    now = OperatorSignUpFlow.database_now
    rows =
      2.times.map do
        OperatorSignUpFlow.create!(
          principal_id: 9_876_543, step: "start", nonce_digest: SecureRandom.hex(32),
          issued_at: now, expires_at: now + 1.minute,
        )
      end
    attributes = {
      result_digest: SecureRandom.hex(32),
      result_generation: 1,
      result_expires_at: now + 30.seconds,
      authentication_event_at: now,
      authentication_method: "passkey",
    }
    rows.first.update_columns(attributes)
    rows.last.assign_attributes(attributes)

    assert_not rows.last.valid?
    assert rows.last.errors.of_kind?(:result_digest, :taken)
    assert_raises(ActiveRecord::RecordNotUnique) do
      OperatorSignUpFlow.transaction(requires_new: true) { rows.last.update_columns(attributes) }
    end
  end

  test "historical result digests remain unique in each realm" do
    [[ClientSignInFlow, ClientSignInFlowState], [OperatorSignInFlow, OperatorSignInFlowState]].each do |model, state|
      state.ensure_defaults!
      now = model.database_now
      rows =
        2.times.map do
          model.create!(
            principal_id: 9_876_543, nonce_digest: SecureRandom.hex(32), issued_at: now,
            expires_at: now + 1.minute,
          )
        end
      attributes = {
        result_digest: SecureRandom.hex(32),
        result_generation: 1,
        result_expires_at: now + 30.seconds,
        authentication_event_at: now,
        authentication_method: "passkey",
      }
      rows.first.update_columns(attributes)
      rows.last.assign_attributes(attributes)

      assert_not rows.last.valid?
      assert rows.last.errors.of_kind?(:result_digest, :taken)
      assert_raises(ActiveRecord::RecordNotUnique) do
        model.transaction(requires_new: true) { rows.last.update_columns(attributes) }
      end
    end
  end
end
