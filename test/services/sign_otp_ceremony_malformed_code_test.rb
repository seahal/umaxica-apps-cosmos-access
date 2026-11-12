# frozen_string_literal: true

require "test_helper"

class SignOtpCeremonyMalformedCodeTest < ActiveSupport::TestCase
  [
    [ClientEmailCeremonyTransaction, :email],
    [ClientTelephoneCeremonyTransaction, :telephone],
  ].each do |model, channel|
    test "app #{channel} malformed code and foreign browser refuse without changing proof" do
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
      original = transaction.reload.attributes
      binding = {
        purpose: "sign_up",
        actor_ref: "original-actor",
        session_ref: "original-browser",
        operation: "sign_up",
        candidate_ref: "original-candidate",
      }
      ["\xFF", "12345", "1234567", "123\0" + "45", "１２３４５６",
       "123456".encode(Encoding::UTF_16LE), 0, false, nil, "",].each do |submitted|
        verified =
          if channel == :email
            transaction.verify_email_otp!(code: submitted, **binding)
          else
            transaction.verify_telephone_otp!(code: submitted, **binding)
          end

        assert_not verified
        assert_withheld("Malformed input must preserve ceremony proof") { original == transaction.reload.attributes }
      end
      [nil, false, 0, "", "another-browser"].each do |browser|
        verified =
          if channel == :email
            transaction.verify_email_otp!(code: code, **binding.merge(session_ref: browser))
          else
            transaction.verify_telephone_otp!(code: code, **binding.merge(session_ref: browser))
          end

        assert_not verified
        assert_withheld("A foreign browser must preserve ceremony proof") { original == transaction.reload.attributes }
      end
    end
  end
end
