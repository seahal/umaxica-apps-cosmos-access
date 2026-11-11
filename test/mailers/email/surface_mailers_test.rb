# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Email::SurfaceMailersTest < ActionMailer::TestCase
  include ActiveJob::TestHelper

  test "APP and ORG OTP messages bound to SMTP use the deadline transport" do
    [Email::App::OtpMailer, Email::Org::OtpMailer].each do |mailer|
      mailer.stub(:delivery_method, :smtp) do
        message = mailer.with(
          encrypted_hotp_token: encrypted_otp("123456"), email_address: "recipient@example.test",
        ).create.message

        assert_instance_of OtpSmtpDelivery, message.delivery_method
      end
    end
  end

  test "app otp mailer sends verification code from app sender" do
    mail = Email::App::OtpMailer.with(
      encrypted_hotp_token: encrypted_otp("123456"),
      email_address: "user@example.com",
      public_id: "email-public-id",
      encrypted_verification_token: OutboundSensitivePayload.encrypt_email_verification_token("verification-token"),
    ).create

    assert_equal I18n.t("mail.email.app.otp_mailer.create.subject"), mail.subject
    assert_equal ["user@example.com"], mail.to
    assert_equal ["otp@umaxica.app"], mail.from
    assert_match "123456", mail.html_part.body.decoded
    assert_not_includes mail.html_part.body.decoded, "verification-token"
  end

  test "app sign-up otp mail uses the purpose-specific subject" do
    mail = Email::App::OtpMailer.with(
      encrypted_hotp_token: encrypted_otp("123456"),
      email_address: "user@example.com",
      purpose: :sign_up,
    ).create

    assert_equal I18n.t("mail.email.app.otp_mailer.create.subjects.sign_up"), mail.subject
    assert_not_includes mail.subject, "123456"
  end

  test "app sign-in otp mail uses the purpose-specific subject" do
    mail = Email::App::OtpMailer.with(
      encrypted_hotp_token: encrypted_otp("123456"),
      email_address: "user@example.com",
      purpose: :sign_in,
    ).create

    assert_equal I18n.t("mail.email.app.otp_mailer.create.subjects.sign_in"), mail.subject
    assert_not_includes mail.subject, "123456"
  end

  test "org otp mailer sends verification code from org sender" do
    mail = Email::Org::OtpMailer.with(
      encrypted_hotp_token: encrypted_otp("999888"),
      email_address: "operator@example.com",
    ).create

    assert_equal I18n.t("mail.email.org.otp_mailer.create.subject"), mail.subject
    assert_equal ["operator@example.com"], mail.to
    assert_equal ["otp@umaxica.org"], mail.from
    assert_match "999888", mail.text_part.body.decoded
  end

  test "app otp mail omits Base-owned email verification links" do
    mail = Email::App::OtpMailer.with(
      encrypted_hotp_token: encrypted_otp("123456"),
      email_address: "target@example.com",
      public_id: "mail-app-public-id",
      encrypted_verification_token: OutboundSensitivePayload.encrypt_email_verification_token("app-token"),
    ).create

    assert_no_match(%r{/identity(?:[/?\s]|$)}, mail.html_part.body.decoded)
    assert_no_match(%r{/identity(?:[/?\s]|$)}, mail.text_part.body.decoded)
    assert_not_includes mail.html_part.body.decoded, "app-token"
    assert_not_includes mail.text_part.body.decoded, "app-token"
  end

  test "org otp mail omits the Base identity verification link" do
    mail = Email::Org::OtpMailer.with(
      encrypted_hotp_token: encrypted_otp("123456"),
      email_address: "target@example.com",
      public_id: "mail-org-public-id",
      encrypted_verification_token: OutboundSensitivePayload.encrypt_email_verification_token("org-token"),
    ).create

    assert_equal ["target@example.com"], mail.to
    assert_no_match(%r{/identity(?:[/?\s]|$)}, mail.html_part.body.decoded)
    assert_no_match(%r{/identity(?:[/?\s]|$)}, mail.text_part.body.decoded)
    assert_not_includes mail.html_part.body.decoded, "org-token"
    assert_not_includes mail.text_part.body.decoded, "org-token"
  end

  test "otp mailer enqueue arguments do not include plaintext otp" do
    clear_enqueued_jobs

    Email::App::OtpMailer.with(
      encrypted_hotp_token: encrypted_otp("112233"),
      email_address: "target@example.com",
    ).create.deliver_later

    job_payload = enqueued_jobs.last[:args].inspect

    assert_includes job_payload, "encrypted_hotp_token"
    assert_no_match(/"hotp_token"\s*=>/, job_payload)
    assert_not_includes job_payload, "112233"
  end

  private

  def encrypted_otp(code)
    OutboundSensitivePayload.encrypt_email_otp(code)
  end
end
