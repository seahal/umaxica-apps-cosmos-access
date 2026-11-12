# frozen_string_literal: true

require "test_helper"

class SmsGovernanceUnavailableTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "bound queued signup and registration OTPs are refused before delivery" do
    bindings = [
      ["app", "sign_up", "flow", SecureRandom.uuid, SecureRandom.uuid],
      ["app", "credential_registration", SecureRandom.uuid, "candidate", SecureRandom.uuid],
      ["org", "credential_registration", SecureRandom.uuid, "a" * 21, SecureRandom.uuid],
    ]
    bindings.each do |binding|
      payload = OutboundSensitivePayload.encrypt_sms_delivery(
        to: "+819012345678", title: "Verification code", body: "Your verification code: 123456", otp_binding: binding,
        otp_code: "123456",
      )
      OutboundSms.stub(:deliver_now, ->(**) { flunk("bound OTP must not be delivered") }) do
        error =
          assert_raises(GovernanceLookupUnavailableError) do
            Outbound::SmsDeliveryJob.perform_now(encrypted_payload: payload)
          end

        assert_not_includes error.message, "123456"
        assert_not_includes error.message, "+819012345678"
      end
    end
  end

  test "a malformed encrypted binding remains reported and never delivered" do
    payload = OutboundSensitivePayload.encrypt(
      JSON.generate(
        version: 3, to: "+819012345678", title: "Verification code", body: "Your verification code: 123456",
        otp_binding: %w(app sign_up flow invalid invalid), otp_code: "123456",
      ),
      purpose: OutboundSensitivePayload::SMS_DELIVERY_PURPOSE,
    )
    reported = []
    OutboundSms.stub(:deliver_now, ->(**) { flunk("invalid OTP must not be delivered") }) do
      ActiveSupport.error_reporter.stub(:report, ->(error, **) { reported << error }) do
        Outbound::SmsDeliveryJob.perform_now(encrypted_payload: payload)
      end
    end

    assert_equal 1, reported.length
    assert_instance_of ArgumentError, reported.first
    assert_not_includes reported.first.message, "123456"
    assert_not_includes reported.first.message, "+819012345678"
  end
  test "a tampered encrypted SMS envelope is rejected before delivery" do
    payload = OutboundSensitivePayload.encrypt_sms_delivery(to: "+819012345678", title: "Notice", body: "Notice")
    tampered = (payload.start_with?("x") ? "y" : "x") + payload[1..]

    OutboundSms.stub(:deliver_now, ->(**) { flunk("tampered SMS must not be delivered") }) do
      assert_raises(ActiveSupport::MessageEncryptor::InvalidMessage) do
        Outbound::SmsDeliveryJob.perform_now(encrypted_payload: tampered)
      end
    end
  end
end
