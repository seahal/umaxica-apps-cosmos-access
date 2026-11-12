# frozen_string_literal: true

require "test_helper"

class OtpLockableTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "the database refuses infinite OTP expiry and the nearest reachable canceled proof is unusable" do
    transaction = ClientEmailCeremonyTransaction.create_transaction!(
      actor_ref: "actor", session_ref: "browser", operation: "sign_in", email_candidate_ref: "candidate",
    )
    code = transaction.issue_email_otp!(purpose: "sign_in")
    assert_raises(ActiveRecord::StatementInvalid) do
      ClientEmailCeremonyTransaction.transaction(requires_new: true) do
        transaction.update_columns(otp_expires_at: Float::INFINITY)
      end
    end
    transaction.reload.cancel_email_otp!

    assert_not transaction.email_otp_deliverable?(
      generation: transaction.otp_generation, at: transaction.class.database_now,
    ), "a positive infinity timestamp is invalid for an authentication OTP"
    assert_not transaction.verify_email_otp!(
      code: code, purpose: "sign_in", actor_ref: "actor", session_ref: "browser",
      operation: "sign_in", candidate_ref: "candidate",
    )
    assert_nil transaction.reload.otp_consumed_at
  end

  test "otp expiry predicates use the owning writer database clock" do
    application_now = Time.current
    database_now = application_now - 1.hour
    transaction = nil
    ClientEmailCeremonyTransaction.stub(:database_now, database_now) do
      transaction = ClientEmailCeremonyTransaction.create_transaction!(
        actor_ref: "actor", session_ref: "browser", operation: "sign_in", email_candidate_ref: "candidate",
        now: database_now, expires_at: application_now + 5.minutes,
      )
      code = transaction.issue_email_otp!(purpose: "sign_in")

      assert transaction.email_otp_deliverable?(generation: transaction.otp_generation, at: database_now)
      assert transaction.deliver_email_otp!(generation: transaction.otp_generation, code: code) { true }
    end

    assert_not transaction.email_otp_deliverable?(generation: transaction.otp_generation, at: application_now)
  end
end
