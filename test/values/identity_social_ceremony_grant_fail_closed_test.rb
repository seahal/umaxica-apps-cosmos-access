# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentitySocialCeremonyGrantFailClosedTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "Access does not sign an Acme grant and malformed wire tokens are refused" do
    now = Time.zone.local(2026, 11, 13, 12)
    attributes = {
      "surface" => "app",
      "actor_ref" => "actor-public-ref",
      "session_ref" => "session-public-ref",
      "transaction_id" => "transaction-public-ref",
      "jti" => "grant-public-ref",
      "operation" => "link",
      "provider" => "google",
      "exp" => (now + 5.minutes).to_i,
    }
    issuer_id = IdentitySocialCeremonyContract.acme_issuer_id("app")

    signing_error =
      assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
        IdentitySocialCeremonyGrant.issue(attributes, issuer_id:, now:)
      end
    assert_includes signing_error.message, "surface:BASE_APP"

    decode_error =
      assert_raises(IdentitySocialCeremonyContract::Error) do
        IdentitySocialCeremonyGrant.decode("not-a-jwt", issuer_id:, now:)
      end
    assert_includes decode_error.message, "token is invalid"
  end
end
