# typed: false
# frozen_string_literal: true

module Email::App
  class OtpMailer < ApplicationMailer
    self.delivery_job = OtpMailDeliveryJob
    default from: "otp@umaxica.app"

    layout "email/application"

    around_deliver :require_governance_delivery_authority!

    OTP_SUBJECT_KEYS = {
      "sign_up" => "mail.email.app.otp_mailer.create.subjects.sign_up",
      "sign_in" => "mail.email.app.otp_mailer.create.subjects.sign_in",
    }.freeze

    def create
      @pass_code = OutboundSensitivePayload.decrypt_email_otp(params[:encrypted_hotp_token])
      reject_plaintext_verification_token!
      @public_id = params[:public_id]

      message = mail(
        to: params[:email_address],
        subject: otp_subject,
      )
      OtpSmtpDelivery.wrap!(message)
    end

    private

    def require_governance_delivery_authority!
      AuthEmailOtpDeliveryBindingValue.for(
        purpose: params[:purpose], auth_ceremony_session_ref: params[:auth_ceremony_session_ref],
        auth_email_otp_generation: params[:auth_email_otp_generation],
      )
      EmailCredentialRegistrationOtpDeliveryBindingValue.for(
        purpose: params[:purpose], contact_ceremony_transaction_ref: params[:contact_ceremony_transaction_ref],
        contact_otp_generation: params[:contact_otp_generation],
      )
      EmailSignUpOtpDeliveryBindingValue.for(
        purpose: params[:purpose], sign_up_flow_ref: params[:sign_up_flow_ref],
        sign_up_email_transaction_ref: params[:sign_up_email_transaction_ref],
        sign_up_email_otp_generation: params[:sign_up_email_otp_generation],
      )
      EmailReentryOtpDeliveryBindingValue.for(
        purpose: params[:purpose], email_ceremony_transaction_ref: params[:email_ceremony_transaction_ref],
        email_otp_generation: params[:email_otp_generation],
      )
      raise GovernanceLookupUnavailableError, "Governance Email OTP delivery authority is unavailable"
    end

    def reject_plaintext_verification_token!
      return unless params.key?(:verification_token) || params.key?("verification_token")

      raise ArgumentError, "plaintext verification tokens are unsupported"
    end

    def otp_subject
      purpose = params[:purpose].to_s
      subject_key = OTP_SUBJECT_KEYS[purpose]
      return I18n.t(subject_key) if subject_key

      I18n.t("mail.email.app.otp_mailer.create.subject")
    end
  end
end
