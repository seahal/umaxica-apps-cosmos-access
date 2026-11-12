# frozen_string_literal: true

require "test_helper"

class StepUpOtpGovernanceUnavailableTest < ActiveSupport::TestCase
  test "retired issuance refuses unavailable Governance contact" do
    assert_raises(GovernanceLookupUnavailableError) do
      Notify::App::StepUpOtpNotifier.issue(record: nil, otp_code: "123456", transaction_ref: "t", generation: 1)
    end
  end

  test "queued delivery refuses unavailable Governance contact" do
    assert_raises(GovernanceLookupUnavailableError) do
      StepUpEmailDeliveryJob.perform_now(
        :email, "Notify::App::StepUpOtpNotifier::Notification",
        recipient: nil,
        params: { transaction_ref: "t", generation: 1, encrypted_hotp_token: "ciphertext" },
      )
    end
  end
end
