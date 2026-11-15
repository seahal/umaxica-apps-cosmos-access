# typed: false
# frozen_string_literal: true

require "aws-sdk-sns"

module Outbound
  class SmsDeliveryJob < ApplicationJob
    queue_as :default

    retry_on Aws::SNS::Errors::ServiceError, wait: :polynomially_longer, attempts: 5
    retry_on Net::OpenTimeout, wait: :polynomially_longer, attempts: 3
    retry_on Net::ReadTimeout, wait: :polynomially_longer, attempts: 3

    # A malformed or mixed payload is a permanent producer/configuration
    # failure. It must not be silently discarded because doing so hides a
    # delivery gap while preserving the no-plaintext-delivery boundary.
    discard_on ArgumentError, report: true

    public

    def perform(encrypted_payload: nil)
      payload = OutboundSensitivePayload.decrypt_sms_delivery(encrypted_payload)
      if payload.key?(:otp_binding)
        case payload.fetch(:otp_binding)[1]
        when "credential_registration" then return deliver_current_registration_otp(payload)
        when "sign_up" then return deliver_current_signup_otp(payload)
        else raise ArgumentError, "unsupported bound SMS purpose"
        end
      end
      OutboundSms.deliver_now(**payload.slice(:to, :title, :body))
    end

    private

    def deliver_current_signup_otp(payload)
      binding = TelephoneSignUpOtpDeliveryBindingValue.for_sms(otp_binding: payload.fetch(:otp_binding))
      raise ArgumentError, "unsupported Telephone signup delivery realm" unless binding.surface == "app"

      raise GovernanceLookupUnavailableError, "Governance Telephone signup delivery authority is unavailable"
    end

    def deliver_current_registration_otp(payload)
      TelephoneCredentialRegistrationOtpDeliveryBindingValue.for_sms(otp_binding: payload.fetch(:otp_binding))
      raise GovernanceLookupUnavailableError, "Governance Telephone registration delivery authority is unavailable"
    end
  end
end
