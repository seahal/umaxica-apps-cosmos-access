# typed: false
# frozen_string_literal: true

require "test_helper"

class OutboundEmailSuspensionInterceptorTest < ActionMailer::TestCase
  setup do
    ActionMailer::Base.deliveries.clear
  end

  teardown do
    Flipper.disable(:outbound_email_suspended)
  end

  test "transactional mail is delivered while no channel is suspended" do
    otp_mail.deliver_now

    assert_equal 1, ActionMailer::Base.deliveries.size
  end

  test "suspending the email channel stops transactional mail" do
    Flipper.enable(:outbound_email_suspended)

    otp_mail.deliver_now

    assert_empty ActionMailer::Base.deliveries
  end

  private

  def otp_mail
    Email::App::OtpMailer.with(
      encrypted_hotp_token: encrypted_otp("123456"),
      email_address: "user@example.com",
      public_id: "email-public-id",
      encrypted_verification_token: OutboundSensitivePayload.encrypt_email_verification_token("verification-token"),
    ).create
  end

  def encrypted_otp(code)
    OutboundSensitivePayload.encrypt_email_otp(code)
  end
end
