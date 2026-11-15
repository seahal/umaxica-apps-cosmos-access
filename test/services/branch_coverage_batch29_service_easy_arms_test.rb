# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch29ServiceEasyArmsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "OidcAccessTokenAuthenticator blank token arms" do
    missing = OidcAccessTokenAuthenticator.new(
      access_token: nil, resource_type: "client", host: "example.test",
    ).call
    blank = OidcAccessTokenAuthenticator.new(
      access_token: "", resource_type: "client", host: "example.test",
    ).call

    assert_equal "invalid_token", missing.error
    assert_not missing.success?
    assert_equal "invalid_token", blank.error
  end

  test "DbscVerificationService blank proof arms" do
    missing_record = DbscVerificationService.new(record: nil, session_id: "s", proof: "p").call
    record = Struct.new(:dbsc_session_id, :dbsc_public_key, :dbsc_challenge, :dbsc_challenge_issued_at)
      .new("s", "k", "c", Time.current)
    missing_proof = DbscVerificationService.new(record: record, session_id: "s", proof: nil).call

    assert_equal "record_missing", missing_record[:error_code]
    assert_equal "missing_proof", missing_proof[:error_code]
  end

  test "SignUpStateMachine blank transition guards" do
    result = SignUpStateMachine.call(ticket: nil, event: :nope, actor_context: {}, payload: {})

    assert_equal :invalid_transition, result.status
    assert_includes result.errors, "unknown event"
  end

  test "SignRiskEnforcer and SignRiskEmitter blank context arms" do
    assert_raises(ArgumentError) { SignRiskEnforcer.call(nil) }
    assert_nil SignRiskEmitter.emit("test")
  end

  test "lib JitSecurityJwtJtiGenerator and KeyMaterial arms" do
    jti = JitSecurityJwtJtiGenerator.generate

    assert_match(/\A[A-Za-z0-9_-]+\z/, jti)
    assert_equal JitSecurityJwtJtiGenerator.encoded_length(20), jti.length
    assert_equal({}, JitSecurityJwtKeyMaterial.parse_private_keyset(nil))
    assert_equal({}, JitSecurityJwtKeyMaterial.parse_private_keyset(""))
  end

  test "lib LocalEnvironment parse arms" do
    assert_nil LocalEnvironment.parse("# comment")[0]
    assert_nil LocalEnvironment.parse("")[0]
    assert_equal %w(FOO bar), LocalEnvironment.parse("FOO=bar")
  end

  test "RefreshTokenable concern currently_usable false arms" do
    token = ClientToken.new
    token.define_singleton_method(:expired?) { |*_args| true }

    assert_not token.currently_usable?
  end
end
