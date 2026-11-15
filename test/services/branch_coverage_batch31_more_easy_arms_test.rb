# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch31MoreEasyArmsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "JitSecurityTurnstileVerifier blank token arms" do
    blank_token = JitSecurityTurnstileVerifier.verify(token: "", remote_ip: "127.0.0.1")

    assert_equal "missing cf-turnstile-response", blank_token["error"]
    nil_token = JitSecurityTurnstileVerifier.verify(token: nil, remote_ip: "127.0.0.1")

    assert_equal "missing cf-turnstile-response", nil_token["error"]
  end

  test "ExternalAuthentication LinkResult and LoginResult rejection arms" do
    assert_raises(ArgumentError) { ExternalAuthentication::LinkResult.new(status: :other, user: Object.new, identity: Object.new) }
    assert_raises(ArgumentError) { ExternalAuthentication::LinkResult.new(status: :linked, user: nil, identity: Object.new) }
    if defined?(ExternalAuthentication::LoginResult)
      assert_raises(ArgumentError) { ExternalAuthentication::LoginResult.new(status: :other, user: Object.new) }
    end
  end

  test "OidcIdTokenIssuer blank nonce and inverted times" do
    client = Struct.new(:client_id, :resource_type).new("base-rails-rp", "client")
    assert_raises(ArgumentError) do
      OidcIdTokenIssuer.new(
        resource_type: "client",
        client: client,
        nonce: "",
        sid: PublicId.generate,
        issued_at: Time.current,
        expires_at: 1.minute.from_now,
      ).call
    end
    assert_raises(ArgumentError) do
      OidcIdTokenIssuer.new(
        resource_type: "client",
        client: client,
        nonce: "n",
        sid: PublicId.generate,
        issued_at: 1.minute.from_now,
        expires_at: Time.current,
      ).call
    end
  end

  test "OIDC access token authenticator blank tokens" do
    assert_raises(ArgumentError) { OidcAccessTokenAuthenticator.new(token: nil) }
    assert_raises(ArgumentError) { OidcAccessTokenAuthenticator.new(token: " ") }
  end

  test "DbscVerificationService blank proof" do
    assert_raises(ArgumentError) do
      DbscVerificationService.new(
        proof: nil, challenge: "c", challenge_issued_at: Time.current,
        expected_audience: "a",
      )
    end
    assert_raises(ArgumentError) do
      DbscVerificationService.new(
        proof: "", challenge: "c", challenge_issued_at: Time.current,
        expected_audience: "a",
      )
    end
  end

  test "ConfigValues OriginValue to_s default and explicit ports" do
    https = ConfigValues.build("https://example.test")

    assert_equal "https://example.test", https.to_s
    http = ConfigValues.build("http://localhost", allow_localhost: true)

    assert_equal "http://localhost", http.to_s
    custom = ConfigValues.build("https://example.test:8443")

    assert_includes custom.to_s, ":8443"
  end

  test "JitSecurityJwtJtiGenerator generate produces strings" do
    a = JitSecurityJwtJtiGenerator.generate
    b = JitSecurityJwtJtiGenerator.generate

    assert_kind_of String, a
    assert_kind_of String, b
    assert_not_equal a, b
  end
end
