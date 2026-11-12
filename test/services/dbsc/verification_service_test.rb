# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class DbscVerificationServiceTest < ActiveSupport::TestCase
  test "verifies proof and returns ok for active user token without changing status" do
    token = client_token
    private_key = OpenSSL::PKey::EC.generate("prime256v1")

    token.update!(
      user_token_binding_method_id: ClientTokenBindingMethod::DBSC,
      user_token_dbsc_status_id: ClientTokenDbscStatus::ACTIVE,
      dbsc_session_id: "session-1",
      dbsc_public_key: { "kty" => "EC" },
      dbsc_challenge: "challenge-1",
      dbsc_challenge_issued_at: Time.current,
    )

    proof = JWT.encode(
      { "jti" => "challenge-1", "aud" => "https://test.host/verification", "iat" => Time.current.to_i },
      private_key, "ES256", { typ: "dbsc+jwt" },
    )

    DbscRecordAdapter.stub(:dbsc_public_key, private_key.public_key) do
      result = DbscVerificationService.call(
        record: token,
        session_id: "session-1",
        proof: proof,
      )

      assert result[:ok]
    end

    assert_equal ClientTokenDbscStatus::ACTIVE, token.reload.user_token_dbsc_status_id
  end

  test "rejects verification proof that carries a public key" do
    token = client_token
    private_key = OpenSSL::PKey::EC.generate("prime256v1")

    token.update!(
      user_token_binding_method_id: ClientTokenBindingMethod::DBSC,
      user_token_dbsc_status_id: ClientTokenDbscStatus::ACTIVE,
      dbsc_session_id: "session-jwk",
      dbsc_public_key: JWT::JWK.new(private_key).export,
      dbsc_challenge: "challenge-jwk",
      dbsc_challenge_issued_at: Time.current,
    )

    proof = JWT.encode(
      { "jti" => "challenge-jwk", "aud" => "https://test.host/verification", "iat" => Time.current.to_i },
      private_key, "ES256", { typ: "dbsc+jwt", jwk: JWT::JWK.new(private_key).export },
    )

    result = DbscVerificationService.call(
      record: token,
      session_id: "session-jwk",
      proof: proof,
    )

    assert_not result[:ok]
    assert_equal "unexpected_public_key", result[:error_code]
  end

  # An unusable stored key must not be reported as invalid_proof: that code
  # blames the client, while these cases are server-side corruption of
  # dbsc_public_key. The distinction drives incident response, because the
  # failure path revokes the refresh session and signs the user out on every
  # attempt.
  test "reports corrupted stored public key as invalid_public_key, not invalid_proof" do
    {
      "unparsable JSON" => "{not-json",
      "JSON that parses to nothing" => "null",
      "unsupported key type" => { "kty" => "bogus" },
      "JWK missing its key type" => { "foo" => "bar" },
      "structurally invalid EC JWK" => { "kty" => "EC" },
      "symmetric key that cannot bind a device" => { "kty" => "oct", "k" => "c2VjcmV0" },
    }.each do |label, stored_key|
      token = dbsc_verification_token_with_stored_key(stored_key)

      result = DbscVerificationService.call(
        record: token,
        session_id: token.dbsc_session_id,
        proof: dbsc_verification_proof(challenge: token.dbsc_challenge),
      )

      assert_not result[:ok], "#{label}: must not verify"
      assert_equal "invalid_public_key", result[:error_code], "#{label}: wrong error code"
    end
  end

  # The resolver must never hand a keyless value to JWT.decode, so it raises
  # rather than returning nil for a key it cannot resolve.
  test "resolving an unusable stored key raises instead of returning nil" do
    ["{not-json", "null", { "kty" => "bogus" }, { "kty" => "oct", "k" => "c2VjcmV0" }].each do |stored_key|
      token = dbsc_verification_token_with_stored_key(stored_key)

      assert_raises(DbscRecordAdapter::PublicKeyError, stored_key.inspect) do
        DbscRecordAdapter.dbsc_public_key(token)
      end
    end
  end

  private

  def dbsc_verification_token_with_stored_key(stored_key)
    token = client_token
    challenge = "challenge-#{SecureRandom.hex(4)}"

    token.update!(
      user_token_binding_method_id: ClientTokenBindingMethod::DBSC,
      user_token_dbsc_status_id: ClientTokenDbscStatus::ACTIVE,
      dbsc_session_id: "session-#{SecureRandom.hex(4)}",
      dbsc_public_key: stored_key,
      dbsc_challenge: challenge,
      dbsc_challenge_issued_at: Time.current,
    )
    token
  end

  def dbsc_verification_proof(challenge:)
    JWT.encode(
      { "jti" => challenge, "aud" => "https://test.host/verification", "iat" => Time.current.to_i },
      OpenSSL::PKey::EC.generate("prime256v1"), "ES256", { typ: "dbsc+jwt" },
    )
  end

  def client_token
    ClientToken.find(ActiveRecord::FixtureSet.identify(:one))
  end
end
