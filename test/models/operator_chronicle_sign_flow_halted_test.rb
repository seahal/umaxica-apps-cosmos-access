# typed: false
# frozen_string_literal: true

require "test_helper"

# D-134: the database makes the ORG halt audit exactly-once per transaction and halt generation.
class OperatorChronicleSignFlowHaltedTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(operator_chronicle_events operator_chronicle_levels)

  setup do
    @base_attributes = {
      actor_type: "Operator",
      actor_id: 123,
      subject_type: "OrgNormalSignInTransaction",
      subject_id: 123,
      event_id: OperatorChronicleEvent::SIGN_FLOW_HALTED,
      occurred_at: Time.current,
    }
  end

  test "generated columns expose the canonical halted-flow identity after PostgreSQL computes it" do
    record = OperatorChronicle.create!(
      @base_attributes.merge(
        context: { transaction_public_id: "txn-projection", halt_generation: 100 },
      ),
    )

    record.reload

    assert_equal "txn-projection", record.read_attribute(:sign_flow_halted_transaction_public_id)
    assert_equal "100", record.read_attribute(:sign_flow_halted_generation)
  end

  test "generated halt identity columns are null for non-halt events" do
    record = OperatorChronicle.create!(
      @base_attributes.merge(
        event_id: OperatorChronicleEvent::LOGGED_IN,
        context: { transaction_public_id: "txn-other-event", halt_generation: 100 },
      ),
    )

    record.reload

    assert_nil record.read_attribute(:sign_flow_halted_transaction_public_id)
    assert_nil record.read_attribute(:sign_flow_halted_generation)
  end

  test "a second SIGN_FLOW_HALTED row for the same transaction and generation is rejected" do
    original = OperatorChronicle.create!(
      @base_attributes.merge(
        context: { transaction_public_id: "txn-a",
                   halt_generation: "100", },
      ),
    )
    duplicate = original.dup

    assert_not_predicate duplicate, :valid?
    assert duplicate.errors.of_kind?(:sign_flow_halted_transaction_public_id, :taken)
    assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
    assert_raises(ActiveRecord::RecordNotUnique) do
      OperatorChronicle.transaction(requires_new: true) { duplicate.save!(validate: false) }
    end
  end

  test "the PostgreSQL unique index rejects duplicate bulk inserts without Rails validation" do
    original = OperatorChronicle.create!(
      @base_attributes.merge(
        context: { transaction_public_id: "txn-bulk-duplicate", halt_generation: "100" },
      ),
    )
    attributes = original.attributes.except(
      "id", "sign_flow_halted_generation", "sign_flow_halted_transaction_public_id",
    )

    assert_raises(ActiveRecord::RecordNotUnique) do
      OperatorChronicle.transaction(requires_new: true) do
        OperatorChronicle.insert_all!([attributes])
      end
    end
  end

  test "halt identity compares extracted keys independently of extra context and JSON scalar types" do
    original = OperatorChronicle.create!(
      @base_attributes.merge(
        context: { transaction_public_id: "txn-context",
                   halt_generation: "100", },
      ),
    )
    duplicate = original.dup
    duplicate.context = {
      transaction_public_id: "txn-context",
      halt_generation: 100,
      reason_code: "another-reason",
      request_id: "another-request",
    }

    assert_not_predicate duplicate, :valid?
    assert duplicate.errors.of_kind?(:sign_flow_halted_transaction_public_id, :taken)

    original.update!(context: original.context.merge("reason_code" => "updated-reason"))

    assert_equal "updated-reason", original.reload.context.fetch("reason_code")
    assert_predicate original, :valid?
  end

  test "JSON key values are quoted as data even when they contain SQL punctuation" do
    original = OperatorChronicle.create!(
      @base_attributes.merge(
        context: { transaction_public_id: "txn' OR true --",
                   halt_generation: "100", },
      ),
    )
    duplicate = original.dup
    duplicate.context = original.context.merge("reason_code" => "another-reason")

    assert_not_predicate duplicate, :valid?
    assert duplicate.errors.of_kind?(:sign_flow_halted_transaction_public_id, :taken)
    unrelated = OperatorChronicle.create!(
      @base_attributes.merge(context: { transaction_public_id: "unrelated-txn", halt_generation: "100" }),
    )

    assert_predicate unrelated, :persisted?
  end

  test "another generation or another transaction is a separate halt" do
    OperatorChronicle.create!(
      @base_attributes.merge(
        context: { transaction_public_id: "txn-b",
                   halt_generation: "100", },
      ),
    )

    assert_nothing_raised do
      OperatorChronicle.create!(
        @base_attributes.merge(
          context: { transaction_public_id: "txn-b",
                     halt_generation: "101", },
        ),
      )
      OperatorChronicle.create!(
        @base_attributes.merge(
          context: { transaction_public_id: "txn-c",
                     halt_generation: "100", },
        ),
      )
    end
  end

  test "a SIGN_FLOW_HALTED row without its correlation keys is rejected" do
    record = OperatorChronicle.new(@base_attributes.merge(context: { reason_code: "phase_violation" }))

    assert_not_predicate record, :valid?
    assert record.errors.of_kind?(:context, :invalid)
    assert_raises(ActiveRecord::RecordInvalid) { record.save! }
    assert_raises(ActiveRecord::StatementInvalid) do
      OperatorChronicle.transaction(requires_new: true) { record.save!(validate: false) }
    end
  end

  test "halt correlation facts require a nonblank string reference and canonical nonnegative generation" do
    [0, 1, "0", "100"].each do |generation|
      record = OperatorChronicle.new(
        @base_attributes.merge(context: { transaction_public_id: " txn-a ", halt_generation: generation }),
      )

      assert_predicate record, :valid?
    end
    invalid_contexts = [
      {},
      { transaction_public_id: nil, halt_generation: "100" },
      { transaction_public_id: "", halt_generation: "100" },
      { transaction_public_id: " \t\r\n ", halt_generation: "100" },
      { transaction_public_id: false, halt_generation: "100" },
      { transaction_public_id: 100, halt_generation: "100" },
      { transaction_public_id: {}, halt_generation: "100" },
    ]
    [nil, "", " ", "\t", false, true, {}, [], -1, "-1", "-0", 0.5, 1.0, "1.0", "01", " 1"].each do |generation|
      invalid_contexts << { transaction_public_id: "txn-a", halt_generation: generation }
    end
    invalid_contexts.each do |context|
      record = OperatorChronicle.new(@base_attributes.merge(context: context))

      assert_not_predicate record, :valid?
      assert record.errors.of_kind?(:context, :invalid)
      error =
        assert_raises(ActiveRecord::StatementInvalid) do
          OperatorChronicle.transaction(requires_new: true) { record.save!(validate: false) }
        end

      assert_instance_of PG::CheckViolation, error.cause
    end
  end

  test "other events are unaffected by the halt index and check" do
    OperatorChronicle.create!(
      @base_attributes.merge(
        context: { transaction_public_id: "shared-txn",
                   halt_generation: "100", },
      ),
    )
    assert_nothing_raised do
      [{}, { transaction_public_id: "shared-txn", halt_generation: "100" }].each do |context|
        2.times do
          OperatorChronicle.create!(
            @base_attributes.merge(
              event_id: OperatorChronicleEvent::LOGGED_IN,
              context: context,
            ),
          )
        end
      end
    end
  end
end
