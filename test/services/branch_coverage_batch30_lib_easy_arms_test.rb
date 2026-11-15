# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch30LibEasyArmsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "JitSecurityJwtJwk normalize_public and validate_public refusal arms" do
    assert_raises(JitSecurityJwtJwk::Error) { JitSecurityJwtJwk.normalize_public([]) }
    assert_raises(JitSecurityJwtJwk::Error) do
      JitSecurityJwtJwk.normalize_public(
        "alg" => JitSecurityJwtJwk::ALGORITHM,
        "use" => "sig",
        "kty" => "EC",
        "kid" => "k",
        "n" => "n",
        "e" => "AQAB",
        "x" => "x",
        "y" => "y",
        "d" => "private",
      )
    end
    assert_raises(JitSecurityJwtJwk::Error) do
      JitSecurityJwtJwk.validate_public!(
        "alg" => JitSecurityJwtJwk::ALGORITHM,
        "use" => "sig",
        "kty" => "RSA",
        "kid" => "k",
        "n" => "AQ",
        "e" => "AQAB",
      )
    end
    assert_raises(JitSecurityJwtJwk::Error) do
      JitSecurityJwtJwk.validate_public!(
        "alg" => JitSecurityJwtJwk::ALGORITHM,
        "use" => "sig",
        "kty" => "EC",
        "kid" => "k",
        "n" => "n",
        "e" => "AQAB",
        "x" => "x",
        "y" => "y",
      )
    end
    assert_raises(JitSecurityJwtJwk::Error) do
      JitSecurityJwtJwk.validate_public!(
        "alg" => "ES256",
        "use" => "sig",
        "kty" => "RSA",
        "kid" => "k",
        "n" => "n",
        "e" => "AQAB",
      )
    end
    assert_raises(JitSecurityJwtJwk::Error) do
      JitSecurityJwtJwk.validate_public!(
        "alg" => JitSecurityJwtJwk::ALGORITHM,
        "use" => "enc",
        "kty" => "RSA",
        "kid" => "k",
        "n" => "n",
        "e" => "AQAB",
      )
    end
  end

  test "SecurityJwtOidcIdTokenCodec build_payload time ordering and claim arms" do
    now = Time.current
    client = Struct.new(:client_id, :resource_type).new("cid", "client")
    assert_raises(ArgumentError) do
      SecurityJwtOidcIdTokenCodec.build_payload(
        resource_type: "client",
        client: client,
        nonce: "n",
        issued_at: now + 1.hour,
        expires_at: now,
        acr: nil,
        amr: nil,
        issuer: "iss",
        subject: "cli_subject",
        sid: "sid",
        auth_time: nil,
        step_up_until: nil,
      )
    end

    payload = SecurityJwtOidcIdTokenCodec.build_payload(
      resource_type: "client",
      client: client,
      nonce: "n",
      issued_at: now,
      expires_at: now + 60,
      acr: nil,
      amr: ["pwd"],
      issuer: "iss",
      subject: "cli_subject",
      sid: "sid",
      auth_time: now,
      step_up_until: now + 30,
    )

    assert_equal ["pwd"], payload["amr"]
    assert payload.key?("auth_time")
    assert payload.key?("step_up_until")
    assert_equal "client", SecurityJwtOidcIdTokenCodec.resource_type_for_client(client)
    assert_equal "operator",
                 SecurityJwtOidcIdTokenCodec.resource_type_for_client(Struct.new(:resource_type).new("staff"))
    operator_client = Struct.new(:resource_type).new("operator")

    assert_equal "operator", SecurityJwtOidcIdTokenCodec.resource_type_for_client(operator_client)
  end

  test "SecurityJwtOidcIdTokenCodec normalizes integer NumericDate inputs" do
    issued_at = 1_800_000_000
    client = Struct.new(:client_id, :resource_type).new("cid", "client")
    payload = SecurityJwtOidcIdTokenCodec.build_payload(
      resource_type: "client",
      client:,
      nonce: "n",
      issued_at:,
      expires_at: issued_at + 60,
      acr: "aal1",
      amr: nil,
      issuer: "iss",
      subject: "cli_subject",
      sid: "sid",
      auth_time: nil,
      step_up_until: nil,
    )

    assert_equal issued_at, payload.fetch("iat")
    assert_equal issued_at + 60, payload.fetch("exp")
  end

  test "SignInSequence expired blank expires_at is expired" do
    seq = SignInSequence.new(id: "1", expires_at: nil)

    assert_predicate seq, :expired?
  end
end
