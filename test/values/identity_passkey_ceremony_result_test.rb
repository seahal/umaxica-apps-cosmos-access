# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentityPasskeyCeremonyResultTest < ActiveSupport::TestCase
  include ActiveSupport::Testing::TimeHelpers

  self.fixture_table_names = []

  test "a signed result round-trips its credential evidence and rejects a changed signature" do
    now = Time.zone.local(2026, 11, 13, 12)
    issuer_id = IdentityPasskeyCeremonyContract.sign_issuer_id("app")
    attributes = {
      "surface" => "app",
      "actor_ref" => "actor-public-ref",
      "session_ref" => "session-public-ref",
      "transaction_id" => "transaction-public-ref",
      "grant_jti" => "grant-public-ref",
      "result_jti" => "result-public-ref",
      "operation" => "registration",
      "verified_at" => now.to_i,
      "challenge_id" => "challenge-public-ref",
      "expires_at" => now.to_i + 5.minutes.to_i,
      "webauthn_id" => "credential-public-ref",
      "public_key" => "verified-public-key",
      "sign_count" => 0,
    }

    travel_to(now) do
      token = IdentityPasskeyCeremonyResult.issue(attributes, issuer_id:, now:)
      result = IdentityPasskeyCeremonyResult.decode(token, issuer_id:, now:)

      assert_equal "actor-public-ref", result["actor_ref"]
      assert_equal "session-public-ref", result["session_ref"]
      assert_equal "webauthn_attestation", result["proof_method"]
      assert_equal "credential-public-ref", result["webauthn_id"]
      assert_equal 0, result["sign_count"]

      tampered_token = "#{token[0...-1]}#{token.end_with?("A") ? "B" : "A"}"
      error =
        assert_raises(IdentityPasskeyCeremonyContract::Error) do
          IdentityPasskeyCeremonyResult.decode(tampered_token, issuer_id:, now:)
        end
      assert_includes error.message, "token verification failed"
    end
  end
end
