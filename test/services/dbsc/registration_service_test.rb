# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class DbscRegistrationServiceTest < ActiveSupport::TestCase
  test "sets user token to active dbsc state" do
    token = client_token
    token.update!(dbsc_challenge: "challenge-1", dbsc_challenge_issued_at: Time.current)
    private_key = OpenSSL::PKey::EC.generate("prime256v1")
    public_jwk = JWT::JWK.new(private_key).export

    proof = JWT.encode(
      { "jti" => "challenge-1", "aud" => "https://test.host/registration", "iat" => Time.current.to_i },
      private_key, "ES256", { typ: "dbsc+jwt", jwk: public_jwk },
    )

    result = DbscRegistrationService.call(record: token, proof: proof, session_id: "dbsc-session-1")

    assert_predicate result[:ok], :present?

    token.reload

    assert_equal ClientTokenBindingMethod::DBSC, token.user_token_binding_method_id
    assert_equal ClientTokenDbscStatus::ACTIVE, token.user_token_dbsc_status_id
    assert_equal "dbsc-session-1", token.dbsc_session_id
    assert_equal public_jwk.stringify_keys, token.dbsc_public_key
    assert_nil token.dbsc_challenge
  end

  test "returns challenge_expired when dbsc_challenge_issued_at is too old" do
    token = client_token
    token.update!(dbsc_challenge: "old-challenge", dbsc_challenge_issued_at: 10.minutes.ago)
    private_key = OpenSSL::PKey::EC.generate("prime256v1")
    public_jwk = JWT::JWK.new(private_key).export

    proof = JWT.encode(
      { "jti" => "old-challenge", "aud" => "https://test.host/registration", "iat" => Time.current.to_i },
      private_key, "ES256", { typ: "dbsc+jwt", jwk: public_jwk },
    )

    result = DbscRegistrationService.call(record: token, proof: proof, session_id: "dbsc-session-x")

    assert_not result[:ok]
    assert_equal "challenge_expired", result[:error_code]
  end

  test "returns challenge_expired when dbsc_challenge_issued_at is blank" do
    token = client_token
    token.update!(dbsc_challenge: "stale-challenge", dbsc_challenge_issued_at: nil)
    private_key = OpenSSL::PKey::EC.generate("prime256v1")
    public_jwk = JWT::JWK.new(private_key).export

    proof = JWT.encode(
      { "jti" => "stale-challenge", "aud" => "https://test.host/registration", "iat" => Time.current.to_i },
      private_key, "ES256", { typ: "dbsc+jwt", jwk: public_jwk },
    )

    result = DbscRegistrationService.call(record: token, proof: proof, session_id: "dbsc-session-y")

    assert_not result[:ok]
    assert_equal "challenge_expired", result[:error_code]
  end

  test "rejects registration proof with mismatched audience" do
    token = client_token
    token.update!(dbsc_challenge: "aud-challenge", dbsc_challenge_issued_at: Time.current)
    private_key = OpenSSL::PKey::EC.generate("prime256v1")
    public_jwk = JWT::JWK.new(private_key).export

    proof = JWT.encode(
      { "jti" => "aud-challenge", "aud" => "https://wrong.host/registration", "iat" => Time.current.to_i },
      private_key, "ES256", { typ: "dbsc+jwt", jwk: public_jwk },
    )

    result = DbscRegistrationService.call(
      record: token,
      proof: proof,
      expected_audience: "https://test.host/registration",
    )

    assert_not result[:ok]
    assert_equal "audience_mismatch", result[:error_code]
    assert_nil token.reload.dbsc_session_id
  end

  test "does not mutate state when the proof envelope is valid but its signature is invalid" do
    token = client_token
    token.update!(dbsc_challenge: "signature-challenge", dbsc_challenge_issued_at: Time.current)
    verification_key = OpenSSL::PKey::EC.generate("prime256v1")
    signing_key = OpenSSL::PKey::EC.generate("prime256v1")
    public_jwk = JWT::JWK.new(verification_key).export

    proof = JWT.encode(
      { "jti" => "signature-challenge", "aud" => "https://test.host/registration", "iat" => Time.current.to_i },
      signing_key,
      "ES256",
      { typ: "dbsc+jwt", jwk: public_jwk },
    )

    result = DbscRegistrationService.call(record: token, proof: proof, session_id: "dbsc-invalid-signature")

    assert_not result[:ok]
    assert_equal "invalid_proof", result[:error_code]
    token.reload

    assert_not_equal "dbsc-invalid-signature", token.dbsc_session_id
    assert_not_equal ClientTokenDbscStatus::ACTIVE, token.user_token_dbsc_status_id
  end

  # The registration JWK comes from the client's own proof header. A symmetric
  # ("oct") JWK would make the stored verification key identical to the signing
  # secret, so whoever registered it could mint valid proofs from any device and
  # the session would no longer be device-bound.
  #
  # Two independent checks reject this today: DbscProofVerifier::ALLOWED_ALGORITHMS
  # excludes HMAC, and DbscRecordAdapter::ASYMMETRIC_KEY_TYPES excludes "oct".
  # The algorithm gate runs first, so that is the code asserted here; the
  # key-type contract is covered directly in the record adapter test. Both are
  # kept because either one alone would leave the invariant implicit.
  test "refuses to bind a session to a symmetric registration JWK" do
    token = client_token
    token.update!(dbsc_challenge: "oct-challenge", dbsc_challenge_issued_at: Time.current)
    shared_secret = "attacker-known-secret"

    proof = JWT.encode(
      { "jti" => "oct-challenge", "aud" => "https://test.host/registration", "iat" => Time.current.to_i },
      shared_secret,
      "HS256",
      { typ: "dbsc+jwt", jwk: { "kty" => "oct", "k" => Base64.urlsafe_encode64(shared_secret, padding: false) } },
    )

    result = DbscRegistrationService.call(record: token, proof: proof, session_id: "dbsc-oct-session")

    assert_not result[:ok]
    assert_equal "invalid_algorithm", result[:error_code]

    token.reload

    assert_nil token.dbsc_public_key
    assert_not_equal "dbsc-oct-session", token.dbsc_session_id
    assert_not_equal ClientTokenDbscStatus::ACTIVE, token.user_token_dbsc_status_id
  end

  private

  def client_token
    ClientToken.find(ActiveRecord::FixtureSet.identify(:one))
  end
end
