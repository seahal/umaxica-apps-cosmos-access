# typed: false
# frozen_string_literal: true

require "test_helper"

# A DPoP proof binds a request to a key the caller holds. Anything it cannot make
# sense of has to be a plain refusal rather than an exception escaping into the
# request, and the request URI it is compared against has to be normalised the
# same way on both sides or a proof for the right request looks like one for the
# wrong request.
class DpopProofRefusalsTest < ActiveSupport::TestCase

  def verifier(proof_jwt:, request_uri: "https://id.example.test/oauth/token")
    DpopProofVerifier.new(
      proof_jwt: proof_jwt, request_method: "POST", request_uri: request_uri, record_jti: false,
    )
  end

  test "a proof that is missing, malformed or undecodable is refused rather than raised" do
    assert_equal "missing_proof", verifier(proof_jwt: "").call.error
    assert_equal "malformed_proof", verifier(proof_jwt: "not-a-jwt").call.error
  end

  test "a proof whose header decodes but whose key material is unusable is refused" do
    unusable = JWT.encode({ "jti" => SecureRandom.uuid, "htm" => "POST" }, nil, "none", { "jwk" => { "kty" => "EC" } })
    result = verifier(proof_jwt: unusable).call

    assert_not result.valid?
    assert_predicate result.error, :present?
  end

end
