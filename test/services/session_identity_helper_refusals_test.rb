# typed: false
# frozen_string_literal: true

require "test_helper"

# Small comparisons and derivations that decide whether a session is spared, an
# address is real, or a proof is trusted. Each
# has one arm that answers conservatively, and each conservative answer is the
# safe one: revoke rather than spare, refuse rather than trust, raise rather than
# guess.
class SessionIdentityHelperRefusalsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  # A stored public key that is not usable JWK material is server-side state, not
  # a client-supplied proof, and is reported separately so operations does not
  # read data corruption as a hijack attempt.
  test "an unusable stored DBSC key is reported apart from an invalid proof" do
    record =
      Struct.new(:dbsc_session_id, :dbsc_public_key, :dbsc_challenge, :dbsc_challenge_issued_at)
        .new("session-1", %({"kty":"oct","k":"c2VjcmV0"}), "challenge", Time.current)
    validator = Object.new
    validator.define_singleton_method(:call) do
      Struct.new(:ok, :error_code, :message, :header).new(true, nil, nil, {})
    end
    service = DbscVerificationService.new(record: record, session_id: "session-1", proof: "proof")
    service.instance_variable_set(:@proof_validator, validator)

    result = service.call

    assert_not result[:ok]
    assert_equal "invalid_public_key", result[:error_code]
  end

  test "a request missing the pieces a DBSC proof needs is refused by name" do
    {
      { record: nil, session_id: "s", proof: "p" } => "record_missing",
      { record: Object.new, session_id: "", proof: "p" } => "missing_session_id",
      { record: Object.new, session_id: "s", proof: "" } => "missing_proof",
    }.each do |arguments, expected|
      result = DbscVerificationService.new(**arguments).call

      assert_not result[:ok]
      assert_equal expected, result[:error_code]
    end
  end
end
