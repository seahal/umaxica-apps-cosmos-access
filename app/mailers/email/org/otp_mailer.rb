# typed: false
# frozen_string_literal: true

module Email::Org
  class OtpMailer < ApplicationMailer
    self.delivery_job = OtpMailDeliveryJob
    default from: "otp@umaxica.org"

    layout "email/application"
    around_deliver :require_governance_delivery_authority!

    def create
      @pass_code = OutboundSensitivePayload.decrypt_email_otp(params[:encrypted_hotp_token])
      reject_plaintext_verification_token!
      @public_id = params[:public_id]

      message = mail(
        to: params[:email_address],
        subject: I18n.t("mail.email.org.otp_mailer.create.subject"),
      )
      OtpSmtpDelivery.wrap!(message)
    end

    private

    def reject_plaintext_verification_token!
      return unless params.key?(:verification_token) || params.key?("verification_token")

      raise ArgumentError, "plaintext verification tokens are unsupported"
    end

    def require_governance_delivery_authority!
      EmailCredentialRegistrationOtpDeliveryBindingValue.for(
        purpose: params[:purpose], contact_ceremony_transaction_ref: params[:contact_ceremony_transaction_ref],
        contact_otp_generation: params[:contact_otp_generation],
      )
      EmailReentryOtpDeliveryBindingValue.for(
        purpose: params[:purpose], email_ceremony_transaction_ref: params[:email_ceremony_transaction_ref],
        email_otp_generation: params[:email_otp_generation],
      )
      raise GovernanceLookupUnavailableError, "Governance Email OTP delivery authority is unavailable"
    end
  end
end
