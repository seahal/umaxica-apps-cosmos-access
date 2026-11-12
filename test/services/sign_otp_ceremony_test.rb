# frozen_string_literal: true

require "test_helper"

class SignOtpCeremonyTest < ActiveSupport::TestCase
  test "Email and Telephone independently bound authentication and confirmation lifetimes" do
    assert_equal 10.minutes, EmailOtpPolicy::MAX_OOB_TTL
    assert_equal EmailOtpPolicy::MAX_OOB_TTL, EmailOtpPolicy::AUTHENTICATION_TTL
    assert_equal EmailOtpPolicy::MAX_OOB_TTL, EmailOtpPolicy::SIGN_UP_CONFIRMATION_TTL
    assert_equal 10.minutes, TelephoneOtpPolicy::MAX_OOB_TTL
    assert_equal TelephoneOtpPolicy::MAX_OOB_TTL, TelephoneOtpPolicy::AUTHENTICATION_TTL
    assert_equal TelephoneOtpPolicy::MAX_OOB_TTL, TelephoneOtpPolicy::SIGN_UP_CONFIRMATION_TTL
  end

  [
    [ClientEmailCeremonyTransaction, :email],
    [ClientTelephoneCeremonyTransaction, :telephone],
  ].each do |model, channel|
    { immediately_before: -1, at: 0, immediately_after: 1 }.each do |boundary, offset|
      test "#{channel} signup proof #{boundary} persisted expiry uses the nearest microsecond" do
        candidate_key = (channel == :email) ? :email_candidate_ref : :telephone_candidate_ref
        now = model.database_now
        transaction = model.create_transaction!(
          :actor_ref => "original-actor", :session_ref => "original-browser", :operation => "sign_up",
          candidate_key => "original-candidate", :expires_at => now + 15.minutes,
        )
        code =
          if channel == :email
            transaction.issue_email_otp!(purpose: "sign_up")
          else
            transaction.issue_telephone_otp!(purpose: "sign_up")
          end
        original = transaction.reload.attributes

        assert_match(/\A[0-9]{6}\z/, code)
        assert_match(/\A[0-9a-f-]{36}\z/, transaction.otp_generation)
        assert_operator transaction.otp_expires_at, :<=, transaction.expires_at
        binding = {
          code: code,
          purpose: "sign_up",
          actor_ref: "original-actor",
          session_ref: "original-browser",
          operation: "sign_up",
          candidate_ref: "original-candidate",
        }
        verified =
          model.stub(:database_now, transaction.otp_expires_at + Rational(offset, 1_000_000)) do
            if channel == :email
              transaction.verify_email_otp!(**binding)
            else
              transaction.verify_telephone_otp!(**binding)
            end
          end

        assert_equal offset.negative?, verified
        if offset >= 0
          assert_withheld("Expired proof must remain unchanged") { original == transaction.reload.attributes }
        end
      end
    end
  end
end
