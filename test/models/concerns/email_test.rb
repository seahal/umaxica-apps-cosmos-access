# frozen_string_literal: true

require "test_helper"

class EmailTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "registration ceremony stores only a keyed verifier and binds its proof to the original candidate" do
    transaction = ClientEmailCeremonyTransaction.create_transaction!(
      actor_ref: "original-actor", session_ref: "original-browser", operation: "registration",
      email_candidate_ref: "original-candidate", normalized_email_digest: "a" * 64,
    )

    assert_nil transaction.otp_expires_at
    assert_not transaction.email_otp_deliverable?(generation: nil, at: ClientEmailCeremonyTransaction.database_now)
    code = transaction.issue_email_otp!(purpose: "credential_registration")
    raw = ClientEmailCeremonyTransaction.where(id: transaction.id).pick(:otp_verifier)

    assert_match(/\A[0-9]{6}\z/, code)
    assert_predicate transaction.otp_generation, :present?
    assert_equal "original-actor", transaction.actor_ref
    assert_equal "original-candidate", transaction.email_candidate_ref
    assert_operator transaction.otp_expires_at, :<=, transaction.expires_at
    assert_equal transaction.reload.otp_verifier, raw
    assert_not_equal code, raw
    assert_not_includes transaction.attributes.values, code
  end

  test "active verifier cannot be cleared directly and cancellation closes delivery" do
    transaction = ClientEmailCeremonyTransaction.create_transaction!(
      actor_ref: "original-actor", session_ref: "original-browser", operation: "registration",
      email_candidate_ref: "original-candidate", normalized_email_digest: "a" * 64,
    )
    code = transaction.issue_email_otp!(purpose: "credential_registration")
    original = transaction.reload.attributes
    assert_raises(ActiveRecord::StatementInvalid) do
      ClientEmailCeremonyTransaction.transaction(requires_new: true) { transaction.update_columns(otp_verifier: nil) }
    end
    assert_equal original, transaction.reload.attributes
    assert transaction.cancel_email_otp!
    assert_not transaction.deliver_email_otp!(generation: transaction.otp_generation, code: code) { true }
  end

  test "registration proof deadline is exclusive and refuses consumption at expiry" do
    transaction = ClientEmailCeremonyTransaction.create_transaction!(
      actor_ref: "original-actor", session_ref: "original-browser", operation: "registration",
      email_candidate_ref: "original-candidate", normalized_email_digest: "a" * 64,
    )
    code = transaction.issue_email_otp!(purpose: "credential_registration")
    deadline = transaction.otp_expires_at
    generation = transaction.otp_generation

    assert transaction.email_otp_deliverable?(generation: generation, at: deadline - Rational(1, 1_000_000))
    assert_not transaction.email_otp_deliverable?(generation: generation, at: deadline)
    assert_not transaction.email_otp_deliverable?(generation: generation, at: deadline + Rational(1, 1_000_000))
    original = transaction.reload.attributes
    verified =
      ClientEmailCeremonyTransaction.stub(:database_now, deadline) do
        transaction.verify_email_otp!(
          code: code, purpose: "credential_registration", actor_ref: "original-actor", session_ref: "original-browser",
          operation: "registration", candidate_ref: "original-candidate",
        )
      end

    assert_not verified
    assert_nil transaction.reload.otp_consumed_at
    assert_equal original, transaction.attributes
  end

  test "registration verification consumes once and retains bounded receipt evidence" do
    transaction = ClientEmailCeremonyTransaction.create_transaction!(
      actor_ref: "original-actor", session_ref: "original-browser", operation: "registration",
      email_candidate_ref: "original-candidate", normalized_email_digest: "a" * 64,
    )
    code = transaction.issue_email_otp!(purpose: "credential_registration")
    generation = transaction.otp_generation
    binding = {
      code: code,
      purpose: "credential_registration",
      actor_ref: "original-actor",
      session_ref: "original-browser",
      operation: "registration",
      candidate_ref: "original-candidate",
    }

    assert transaction.verify_email_otp!(**binding)
    assert_not transaction.verify_email_otp!(**binding)
    assert transaction.email_otp_verified_evidence?(**binding)
    transaction.reload

    assert_nil transaction.otp_verifier
    assert_equal generation, transaction.otp_generation
    assert_predicate transaction.otp_receipt_verifier, :present?
    assert_equal transaction.otp_consumed_at + 60.seconds, transaction.otp_result_expires_at
    original = transaction.attributes
    assert_raises(ActiveRecord::StatementInvalid) do
      ClientEmailCeremonyTransaction.transaction(requires_new: true) do
        transaction.update_columns(otp_consumed_at: nil, otp_receipt_verifier: nil, otp_result_expires_at: nil)
      end
    end
    assert_equal original, transaction.reload.attributes
  end
end
