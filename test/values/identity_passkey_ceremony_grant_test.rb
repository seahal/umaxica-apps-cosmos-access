# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentityPasskeyCeremonyGrantTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "grant claims validate while Access refuses to sign with the absent Base key" do
    now = Time.zone.local(2026, 11, 13, 12)
    attributes = {
      "surface" => "app",
      "actor_ref" => "actor-public-ref",
      "session_ref" => "session-public-ref",
      "transaction_id" => "transaction-public-ref",
      "jti" => "grant-public-ref",
      "operation" => "registration",
      "exp" => (now + 5.minutes).to_i,
    }
    payload = attributes.merge(IdentityPasskeyCeremonyGrant.default_claims(attributes, now:))
    grant = IdentityPasskeyCeremonyGrant.new(payload, now:)

    assert_equal "passkey_ceremony", grant["purpose"]
    assert_equal "actor-public-ref", grant["actor_ref"]

    signing_error =
      assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
        IdentityPasskeyCeremonyGrant.issue(
          attributes,
          issuer_id: IdentityPasskeyCeremonyContract.acme_issuer_id("app"),
          now:,
        )
      end
    assert_includes signing_error.message, "surface:BASE_APP"

    decode_error =
      assert_raises(IdentityPasskeyCeremonyContract::Error) do
        IdentityPasskeyCeremonyGrant.decode(
          "not-a-jwt",
          issuer_id: IdentityPasskeyCeremonyContract.acme_issuer_id("app"),
          now:,
        )
      end
    assert_includes decode_error.message, "token is invalid"
  end
end
