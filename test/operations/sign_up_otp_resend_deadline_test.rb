# frozen_string_literal: true

require "test_helper"

class SignUpOtpResendDeadlineTest < ActiveSupport::TestCase
  [
    [:email, ClientEmailCeremonyTransaction],
    [:telephone, ClientTelephoneCeremonyTransaction],
  ].product([[:before, -1], [:at, 0], [:after, 1]]).each do |(channel, model), (label, offset)|
    test "#{channel} signup OTP reissue at #{label} the original deadline" do
      candidate_key = (channel == :email) ? :email_candidate_ref : :telephone_candidate_ref
      transaction = model.create_transaction!(
        :actor_ref => "original-actor", :session_ref => "original-browser", :operation => "sign_up",
        candidate_key => "original-candidate",
      )
      if channel == :email
        transaction.issue_email_otp!(purpose: "sign_up")
      else
        transaction.issue_telephone_otp!(purpose: "sign_up")
      end
      original = transaction.reload.attributes
      decision_time = transaction.otp_expires_at + Rational(offset, 1_000_000)

      model.stub(:database_now, decision_time) do
        if label == :before
          if channel == :email
            transaction.reissue_email_otp!
          else
            transaction.reissue_telephone_otp!
          end
        else
          assert_raises(ArgumentError) do
            if channel == :email
              transaction.reissue_email_otp!
            else
              transaction.reissue_telephone_otp!
            end
          end
        end
      end
      transaction.reload
      if label == :before
        assert_not_equal original.fetch("otp_generation"), transaction.otp_generation
        assert_equal original.fetch("otp_expires_at"), transaction.otp_expires_at
        assert_equal original.fetch("expires_at"), transaction.expires_at
      else
        assert_withheld("expired refusal preserves the original proof") { original == transaction.attributes }
      end
    end
  end
end
