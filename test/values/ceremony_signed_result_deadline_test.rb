# frozen_string_literal: true

require "test_helper"

class CeremonySignedResultDeadlineTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  self.fixture_table_names = []

  %w(app org).each do |surface|
    [-1, 0, 1].each do |seconds|
      test "#{surface} step-up signed result at deadline #{seconds} seconds accepts only future NumericDate" do
        decision_time = Time.zone.local(2026, 10, 7, 12)
        issued_at = decision_time - 2.seconds
        deadline = decision_time.to_i + seconds
        issuer_id = IdentityStepUpCeremonyContract.sign_issuer_id(surface)
        attributes = {
          "surface" => surface,
          "actor_ref" => "bound-actor-public-ref",
          "session_ref" => "bound-session-public-ref",
          "transaction_id" => "bound-transaction-ref",
          "grant_jti" => "bound-grant-ref",
          "result_jti" => SecureRandom.uuid,
          "verified_at" => issued_at.to_i,
          "challenge_id" => "bound-challenge-ref",
          "scope" => "settings_email",
          "aal" => "none",
          "method" => "passkey",
          "phishing_resistant" => true,
          "user_verified" => true,
          "credential_ref" => "bound-credential-ref",
          "full_reauthentication" => false,
          "expires_at" => deadline,
        }
        token = IdentityStepUpCeremonyResult.issue(attributes, issuer_id:, now: issued_at)

        travel_to(decision_time) do
          if seconds.positive?
            result = IdentityStepUpCeremonyResult.decode(token, issuer_id:, now: decision_time)

            assert_equal [surface, deadline, deadline, "bound-actor-public-ref", "bound-session-public-ref"],
                         [result["surface"], result["exp"], result["expires_at"], result["actor_ref"],
                          result["session_ref"],]
          else
            error =
              assert_raises(IdentityStepUpCeremonyContract::Error) do
                IdentityStepUpCeremonyResult.decode(token, issuer_id:, now: decision_time)
              end

            assert_includes error.message, "expired"
          end
        end
      end
    end
  end
end
