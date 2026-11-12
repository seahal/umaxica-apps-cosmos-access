# frozen_string_literal: true

require "test_helper"

class TelephoneTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "registration ceremony stores only a keyed verifier and binds its proof to the original candidate" do
    transaction = OperatorTelephoneCeremonyTransaction.create_transaction!(
      actor_ref: "original-actor", session_ref: "original-browser", operation: "registration",
      telephone_candidate_ref: "original-candidate", normalized_number_digest: "a" * 64,
    )

    assert_nil transaction.otp_expires_at
    assert_not transaction.telephone_otp_deliverable?(
      generation: nil,
      at: OperatorTelephoneCeremonyTransaction.database_now,
    )
    code = transaction.issue_telephone_otp!(purpose: "credential_registration")
    raw = OperatorTelephoneCeremonyTransaction.where(id: transaction.id).pick(:otp_verifier)

    assert_match(/\A[0-9]{6}\z/, code)
    assert_predicate transaction.otp_generation, :present?
    assert_equal "original-actor", transaction.actor_ref
    assert_equal "original-candidate", transaction.telephone_candidate_ref
    assert_operator transaction.otp_expires_at, :<=, transaction.expires_at
    assert_operator transaction.otp_expires_at, :>, transaction.created_at
    assert_equal transaction.reload.otp_verifier, raw
    assert_not_equal code, raw
    assert_not_includes transaction.attributes.values, code
  end

  test "active verifier cannot be cleared directly and cancellation closes delivery" do
    transaction = OperatorTelephoneCeremonyTransaction.create_transaction!(
      actor_ref: "original-actor", session_ref: "original-browser", operation: "registration",
      telephone_candidate_ref: "original-candidate", normalized_number_digest: "a" * 64,
    )
    code = transaction.issue_telephone_otp!(purpose: "credential_registration")
    original = transaction.reload.attributes
    assert_raises(ActiveRecord::StatementInvalid) do
      OperatorTelephoneCeremonyTransaction.transaction(requires_new: true) {
        transaction.update_columns(otp_verifier: nil)
      }
    end
    assert_equal original, transaction.reload.attributes
    proof_facts = transaction.attributes.slice("otp_generation", "otp_expires_at")

    assert transaction.cancel_telephone_otp!
    assert_nil transaction.reload.otp_verifier
    assert_predicate transaction.otp_cancelled_at, :present?
    assert_equal proof_facts, transaction.attributes.slice(*proof_facts.keys)
    assert_not transaction.deliver_telephone_otp!(generation: transaction.otp_generation, code: code) { true }
  end

  test "registration proof deadline is exclusive and refuses consumption at expiry" do
    transaction = OperatorTelephoneCeremonyTransaction.create_transaction!(
      actor_ref: "original-actor", session_ref: "original-browser", operation: "registration",
      telephone_candidate_ref: "original-candidate", normalized_number_digest: "a" * 64,
    )
    code = transaction.issue_telephone_otp!(purpose: "credential_registration")
    deadline = transaction.otp_expires_at
    generation = transaction.otp_generation

    assert transaction.telephone_otp_deliverable?(generation: generation, at: deadline - Rational(1, 1_000_000))
    assert_not transaction.telephone_otp_deliverable?(generation: generation, at: deadline)
    assert_not transaction.telephone_otp_deliverable?(generation: generation, at: deadline + Rational(1, 1_000_000))
    original = transaction.reload.attributes
    verified =
      OperatorTelephoneCeremonyTransaction.stub(:database_now, deadline) do
        transaction.verify_telephone_otp!(
          code: code, purpose: "credential_registration", actor_ref: "original-actor", session_ref: "original-browser",
          operation: "registration", candidate_ref: "original-candidate",
        )
      end

    assert_not verified
    assert_nil transaction.reload.otp_consumed_at
    assert_equal original, transaction.attributes
  end

  test "registration verification consumes once and retains bounded receipt evidence" do
    transaction = OperatorTelephoneCeremonyTransaction.create_transaction!(
      actor_ref: "original-actor", session_ref: "original-browser", operation: "registration",
      telephone_candidate_ref: "original-candidate", normalized_number_digest: "a" * 64,
    )
    code = transaction.issue_telephone_otp!(purpose: "credential_registration")
    generation = transaction.otp_generation
    binding = {
      code: code,
      purpose: "credential_registration",
      actor_ref: "original-actor",
      session_ref: "original-browser",
      operation: "registration",
      candidate_ref: "original-candidate",
    }

    assert transaction.verify_telephone_otp!(**binding)
    assert_not transaction.verify_telephone_otp!(**binding)
    assert transaction.telephone_otp_verified_evidence?(**binding)
    transaction.reload

    assert_nil transaction.otp_verifier
    assert_equal generation, transaction.otp_generation
    assert_predicate transaction.otp_receipt_verifier, :present?
    assert_equal transaction.otp_consumed_at + 60.seconds, transaction.otp_result_expires_at
    original = transaction.attributes
    assert_raises(ActiveRecord::StatementInvalid) do
      OperatorTelephoneCeremonyTransaction.transaction(requires_new: true) do
        transaction.update_columns(otp_consumed_at: nil, otp_receipt_verifier: nil, otp_result_expires_at: nil)
      end
    end
    assert_equal original, transaction.reload.attributes
  end
end
