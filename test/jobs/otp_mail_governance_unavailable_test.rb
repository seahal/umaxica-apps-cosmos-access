# frozen_string_literal: true

require "test_helper"

class OtpMailGovernanceUnavailableTest < ActiveJob::TestCase
  self.fixture_table_names = []

  test "queued OTP mail cannot deliver without Governance authority in either realm" do
    generation = SecureRandom.uuid
    transaction = SecureRandom.uuid
    cases = [
      ["Email::App::OtpMailer", { purpose: "sign_in",
                                  auth_ceremony_session_ref: "42",
                                  auth_email_otp_generation: generation, },],
      ["Email::App::OtpMailer", { purpose: "sign_up",
                                  sign_up_flow_ref: "flow",
                                  sign_up_email_transaction_ref: transaction,
                                  sign_up_email_otp_generation: generation, },],
      ["Email::App::OtpMailer", { purpose: "credential_registration",
                                  contact_ceremony_transaction_ref: transaction,
                                  contact_otp_generation: generation, },],
      ["Email::Org::OtpMailer", { purpose: "credential_registration",
                                  contact_ceremony_transaction_ref: transaction,
                                  contact_otp_generation: generation, },],
      ["Email::App::OtpMailer", { purpose: "recovery",
                                  email_ceremony_transaction_ref: transaction,
                                  email_otp_generation: generation, },],
      ["Email::Org::OtpMailer", { purpose: "withdrawal",
                                  email_ceremony_transaction_ref: transaction,
                                  email_otp_generation: generation, },],
    ]
    cases.each do |mailer, binding|
      params = binding.merge(
        encrypted_hotp_token: OutboundSensitivePayload.encrypt_email_otp("123456"),
        email_address: "recipient@example.test", public_id: "email-public-id",
      )
      before = ActionMailer::Base.deliveries.length
      error =
        assert_raises(GovernanceLookupUnavailableError) do
          OtpMailDeliveryJob.perform_now(mailer, "create", "deliver_now", params: params, args: [])
        end

      assert_equal before, ActionMailer::Base.deliveries.length
      assert_not_includes error.message, "123456"
      assert_not_includes error.message, "recipient@example.test"
    end
  end

  test "queued OTP mail rejects malformed bindings before delivery" do
    params = {
      encrypted_hotp_token: OutboundSensitivePayload.encrypt_email_otp("123456"),
      email_address: "recipient@example.test",
      purpose: "credential_registration",
      contact_ceremony_transaction_ref: "invalid",
      contact_otp_generation: "invalid",
    }
    before = ActionMailer::Base.deliveries.length
    error =
      assert_raises(ArgumentError) do
        OtpMailDeliveryJob.perform_now("Email::App::OtpMailer", "create", "deliver_now", params: params, args: [])
      end

    assert_equal before, ActionMailer::Base.deliveries.length
    assert_not_includes error.message, "123456"
    assert_not_includes error.message, "recipient@example.test"
  end
  test "tampered encrypted OTP mail is rejected before delivery" do
    encrypted = OutboundSensitivePayload.encrypt_email_otp("123456")
    tampered = (encrypted.start_with?("x") ? "y" : "x") + encrypted[1..]
    params = { encrypted_hotp_token: tampered, email_address: "recipient@example.test" }
    before = ActionMailer::Base.deliveries.length

    assert_raises(ActiveSupport::MessageEncryptor::InvalidMessage) do
      OtpMailDeliveryJob.perform_now("Email::App::OtpMailer", "create", "deliver_now", params: params, args: [])
    end
    assert_equal before, ActionMailer::Base.deliveries.length
  end
end
