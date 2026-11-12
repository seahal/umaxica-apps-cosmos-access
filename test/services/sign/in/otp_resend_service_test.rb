# frozen_string_literal: true

require "test_helper"

module Sign
  module In
    class OtpResendServiceTest < ActiveSupport::TestCase
      setup do
        admission = OidcTestEntry.issue!(
          surface: :app, intent: "sign_in", base_browser_nonce: SecureRandom.hex(32), base_token: nil,
        )
        @ceremonies = {
          app: ClientAuthCeremonySession.rotate_and_admit!(
            admission_purpose: "authentication_handoff",
            authorization_transaction_ref: admission.transaction.transaction_id,
          ).first,
        }
      end

      { before: -Rational(1, 1_000_000), at: 0, after: Rational(1, 1_000_000) }.each do |boundary, offset|
        test "locked sign-in resend checks the old OTP deadline #{boundary} expiry" do
          address = "locked-deadline-#{SecureRandom.hex(8)}@example.test"
          ceremony = @ceremonies.fetch(:app)
          ceremony.issue_email_otp!(contact: nil, destination: address)
          previous = ceremony.reload.email_otp_context.deep_dup
          deadline = Time.iso8601(previous.fetch("expires_at"))

          result =
            ClientAuthCeremonySession.stub(:database_now, deadline + offset) do
              ceremony.issue_email_otp!(
                contact: nil, destination: address, expected_generation: previous.fetch("generation"),
              )
            end

          if boundary == :before
            assert_nil result
            assert_not_equal previous.fetch("generation"), ceremony.reload.email_otp_context.fetch("generation")
          else
            assert_same false, result
            assert_withheld { previous == ceremony.reload.email_otp_context }
          end
        end
      end

      test "locked sign-in resend cannot overwrite a replaced generation" do
        address = "locked-generation-#{SecureRandom.hex(8)}@example.test"
        ceremony = @ceremonies.fetch(:app)
        ceremony.issue_email_otp!(contact: nil, destination: address)
        previous_generation = ceremony.reload.email_otp_context.fetch("generation")
        ceremony.issue_email_otp!(contact: nil, destination: address)
        replacement = ceremony.reload.email_otp_context.deep_dup

        assert_same false, ceremony.issue_email_otp!(
          contact: nil, destination: address, expected_generation: previous_generation,
        )
        assert_withheld { replacement == ceremony.reload.email_otp_context }
      end
    end
  end
end
