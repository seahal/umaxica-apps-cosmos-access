# frozen_string_literal: true

require "test_helper"

class SignupOtpDeliveryPayloadTest < ActiveJob::TestCase
  self.fixture_table_names = []

  test "queued email retains binding and encrypts its OTP" do
    transaction = SecureRandom.uuid
    generation = SecureRandom.uuid
    encrypted = OutboundSensitivePayload.encrypt_email_otp("001234")
    clear_enqueued_jobs
    Email::App::OtpMailer.with(
      encrypted_hotp_token: encrypted, email_address: "recipient@example.test", public_id: "candidate",
      purpose: "sign_up", sign_up_flow_ref: "flow_ref", sign_up_email_transaction_ref: transaction,
      sign_up_email_otp_generation: generation,
    ).create.deliver_later

    assert_equal 1, enqueued_jobs.length
    job = enqueued_jobs.first
    arguments = job.fetch(:args)
    params = arguments.last.fetch("params")

    assert_not job.fetch(:job).log_arguments
    assert_equal "flow_ref", params.fetch("sign_up_flow_ref")
    assert_equal transaction, params.fetch("sign_up_email_transaction_ref")
    assert_equal generation, params.fetch("sign_up_email_otp_generation")
    assert_equal "candidate", params.fetch("public_id")
    assert_equal "001234", OutboundSensitivePayload.decrypt_email_otp(params.fetch("encrypted_hotp_token"))
    assert_not_includes arguments.to_s, "001234"
  end

  test "queued signup SMS retains binding and encrypts destination and OTP" do
    transaction = SecureRandom.uuid
    generation = SecureRandom.uuid
    binding = ["app", "sign_up", "flow_ref", transaction, generation]
    encrypted = OutboundSensitivePayload.encrypt_sms_delivery(
      to: "+819012345670", title: "Verification code", body: "Your verification code: 001234",
      otp_binding: binding, otp_code: "001234",
    )
    clear_enqueued_jobs
    Outbound::SmsDeliveryJob.perform_later(encrypted_payload: encrypted)

    assert_equal 1, enqueued_jobs.length
    arguments = enqueued_jobs.first.fetch(:args)
    payload = OutboundSensitivePayload.decrypt_sms_delivery(arguments.first.fetch("encrypted_payload"))

    assert_equal 3, payload.fetch(:version)
    assert_equal binding, payload.fetch(:otp_binding)
    assert_equal "+819012345670", payload.fetch(:to)
    assert_equal "001234", payload.fetch(:otp_code)
    assert_not_includes arguments.to_s, "001234"
    assert_not_includes arguments.to_s, "+819012345670"
  end
end
