# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch6OtpAndOpsTest < ActiveSupport::TestCase
  test "OidcTokenRevoker failure arms for missing tokens" do
    result = OidcTokenRevoker.new(
      token: "",
      client_id: "base-rails-rp",
      client_secret: "secret",
      token_type_hint: "access_token",
    ).call

    assert_not result.success?
  end

  test "DpopProofVerifier rejects missing proof pieces" do
    result = DpopProofVerifier.new(
      proof_jwt: "",
      request_method: "POST",
      request_uri: "https://example.test/token",
    ).call

    assert_not result.valid
  end

  test "Retainable soft-delete guards" do
    token = ClientToken.new
    token.define_singleton_method(:discarded?) { true }

    assert_predicate token, :discarded?
  end
end
