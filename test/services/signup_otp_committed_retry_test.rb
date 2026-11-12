# frozen_string_literal: true

require "test_helper"

class SignupOtpCommittedRetryTest < ActiveSupport::TestCase
  [
    [ClientEmailCeremonyTransaction, :email],
    [ClientTelephoneCeremonyTransaction, :telephone],
  ].each do |model, channel|
    test "app #{channel} signup committed proof remains bound and never grants fresh authority" do
      candidate_key = (channel == :email) ? :email_candidate_ref : :telephone_candidate_ref
      transaction = model.create_transaction!(
        :actor_ref => "original-actor", :session_ref => "original-browser", :operation => "sign_up",
        candidate_key => "original-candidate",
      )
      code =
        if channel == :email
          transaction.issue_email_otp!(purpose: "sign_up")
        else
          transaction.issue_telephone_otp!(purpose: "sign_up")
        end
      binding = {
        purpose: "sign_up",
        actor_ref: "original-actor",
        session_ref: "original-browser",
        operation: "sign_up",
        candidate_ref: "original-candidate",
      }
      first =
        if channel == :email
          transaction.verify_email_otp!(code: code, **binding)
        else
          transaction.verify_telephone_otp!(code: code, **binding)
        end

      assert first
      proof = transaction.reload.attributes

      assert_nil transaction.otp_verifier
      assert_not proof.values.include?(code), "committed proof must not persist the raw OTP"
      deadline = transaction.otp_result_expires_at
      [-Rational(1, 1_000_000), 0, Rational(1, 1_000_000)].each do |offset|
        evidence =
          model.stub(:database_now, deadline + offset) do
            if channel == :email
              transaction.email_otp_verified_evidence?(code: code, **binding)
            else
              transaction.telephone_otp_verified_evidence?(code: code, **binding)
            end
          end

        assert_equal offset.negative?, evidence
        assert_withheld("Retry preserves committed proof") { proof == transaction.reload.attributes }
      end
      wrong_code = (code == "000000") ? "000001" : "000000"
      [[wrong_code, binding], [code, binding.merge(session_ref: "foreign-browser")]].each do |submitted, scope|
        evidence =
          if channel == :email
            transaction.email_otp_verified_evidence?(code: submitted, **scope)
          else
            transaction.telephone_otp_verified_evidence?(code: submitted, **scope)
          end

        assert_not evidence
        assert_withheld("Refusal preserves committed proof") { proof == transaction.reload.attributes }
      end
      replay =
        if channel == :email
          transaction.verify_email_otp!(code: code, **binding)
        else
          transaction.verify_telephone_otp!(code: code, **binding)
        end

      assert_not replay
      assert_withheld("Replay cannot rewrite proof") { proof == transaction.reload.attributes }
    end
  end
end
