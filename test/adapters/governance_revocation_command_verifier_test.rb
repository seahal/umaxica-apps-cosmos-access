# frozen_string_literal: true

require "minitest/autorun"
require "minitest/mock"
require "jwt"
require "openssl"
require "faraday"
require_relative "../../app/lib/outbound_http/connection"
require_relative "../../app/values/governance_revocation_command_value"
require_relative "../../app/adapters/governance_revocation_command_verifier"

class GovernanceRevocationCommandVerifierTest < Minitest::Test
  def test_key_identifier_and_rotation_key_count_boundaries
    key = OpenSSL::PKey::EC.generate("secp384r1")
    payload = {
      "iss" => "https://governance.example",
      "aud" => "https://visa.example",
      "iat" => 1_000,
      "exp" => 1_060,
      "jti" => "11111111-1111-4111-8111-111111111111",
      "realm" => "app",
      "sub" => "cli_existing",
      "scope" => "all_sessions",
      "actor" => "opr_operator",
      "reason" => "account_disabled",
    }
    [0, 1, 2, 127, 128, 129].each do |length|
      kid = "x" * length
      jwk = JSON.parse(JSON.generate(JWT::JWK.new(key, kid).export.merge(alg: "ES384", use: "sig")))
      token = JWT.encode(payload, key, "ES384", { kid:, typ: "governance-revocation+jwt" })
      verifier = GovernanceRevocationCommandVerifier.new(
        issuer: payload.fetch("iss"), audience: payload.fetch("aud"), realm: "app",
        jwks_url: "https://governance.example/keys", fetcher: -> { { "keys" => [jwk] } }, now: Time.at(1_000).utc,
      )
      if length.between?(1, 128)
        assert_equal "existing", verifier.verify(token).principal_public_id
      else
        assert_raises(GovernanceRevocationCommandVerifier::Rejected) { verifier.verify(token) }
      end
    end
    token = JWT.encode(payload, key, "ES384", { kid: "primary", typ: "governance-revocation+jwt" })
    jwk = JSON.parse(JSON.generate(JWT::JWK.new(key, "primary").export.merge(alg: "ES384", use: "sig")))
    [0, 1, 2, 9, 10, 11].each do |count|
      keys = count.times.map { |index| jwk.merge("kid" => index.zero? ? "primary" : "rotation-#{index}") }
      verifier = GovernanceRevocationCommandVerifier.new(
        issuer: payload.fetch("iss"), audience: payload.fetch("aud"), realm: "app",
        jwks_url: "https://governance.example/keys", fetcher: -> { { "keys" => keys } }, now: Time.at(1_000).utc,
      )
      if count.between?(1, 10)
        assert_equal "existing", verifier.verify(token).principal_public_id
      else
        assert_raises(GovernanceRevocationCommandVerifier::Unavailable) { verifier.verify(token) }
      end
    end
  end

  def test_http_key_fetch_requires_public_https_timeouts_and_accepts_the_last_two_body_sizes
    key = OpenSSL::PKey::EC.generate("secp384r1")
    jwks = JSON.generate(keys: [JWT::JWK.new(key, "governance-key").export.merge(alg: "ES384", use: "sig")])
    payload = {
      "iss" => "https://governance.example",
      "aud" => "https://visa.example",
      "iat" => 1_000,
      "exp" => 1_060,
      "jti" => "11111111-1111-4111-8111-111111111111",
      "realm" => "app",
      "sub" => "cli_existing",
      "scope" => "all_sessions",
      "actor" => "opr_operator",
      "reason" => "account_disabled",
    }
    token = JWT.encode(payload, key, "ES384", { kid: "governance-key", typ: "governance-revocation+jwt" })
    [jwks.ljust(65_535), jwks.ljust(65_536)].each do |body|
      network = Faraday.new
      transport =
        lambda do |url, &configure|
          assert_equal "https://governance.example/keys", url.to_s
          request = Faraday::Request.new
          request.options = Faraday::RequestOptions.new
          configure.call(request)
          request.options.on_data.call(body, body.bytesize)
          Faraday::Response.new(status: 200, body: "")
        end
      verifier = GovernanceRevocationCommandVerifier.new(
        issuer: payload.fetch("iss"), audience: payload.fetch("aud"), realm: "app",
        jwks_url: "https://governance.example/keys", now: Time.at(1_000).utc,
      )

      network.stub(:get, transport) do
        OutboundHttp::Connection.stub(
          :build, lambda { |**options|
            assert options.fetch(:require_public_address)
            assert options.fetch(:require_https)
            assert_equal [1, 2, 2], options.values_at(:open_timeout, :read_timeout, :write_timeout)
            network
          },
        ) do
          assert_equal "existing", verifier.verify(token).principal_public_id
        end
      end
    end
  end

  def test_http_key_fetch_refuses_errors_timeouts_malformed_json_and_the_first_oversized_body
    key = OpenSSL::PKey::EC.generate("secp384r1")
    jwks = JSON.generate(keys: [JWT::JWK.new(key, "governance-key").export.merge(alg: "ES384", use: "sig")])
    payload = {
      "iss" => "https://governance.example",
      "aud" => "https://visa.example",
      "iat" => 1_000,
      "exp" => 1_060,
      "jti" => "11111111-1111-4111-8111-111111111111",
      "realm" => "app",
      "sub" => "cli_existing",
      "scope" => "all_sessions",
      "actor" => "opr_operator",
      "reason" => "account_disabled",
    }
    token = JWT.encode(payload, key, "ES384", { kid: "governance-key", typ: "governance-revocation+jwt" })
    [[503, ""], [200, "invalid JSON"], [0, nil], [-1, nil], [200, jwks.ljust(65_537)]].each do |status, body|
      network = Faraday.new
      transport =
        lambda do |_url, &configure|
          raise Faraday::TimeoutError if status.zero?
          raise OutboundHttp::Connection::InsecureEndpointError if status.negative?

          request = Faraday::Request.new
          request.options = Faraday::RequestOptions.new
          configure.call(request)
          request.options.on_data.call(body, body.bytesize)
          Faraday::Response.new(status:, body: "")
        end
      verifier = GovernanceRevocationCommandVerifier.new(
        issuer: payload.fetch("iss"), audience: payload.fetch("aud"), realm: "app",
        jwks_url: "https://governance.example/keys", now: Time.at(1_000).utc,
      )

      network.stub(:get, transport) do
        OutboundHttp::Connection.stub(:build, network) do
          assert_raises(GovernanceRevocationCommandVerifier::Unavailable) { verifier.verify(token) }
        end
      end
    end
  end

  def test_only_the_configured_governance_key_and_explicit_token_type_are_accepted
    key = OpenSSL::PKey::EC.generate("secp384r1")
    attacker_key = OpenSSL::PKey::EC.generate("secp384r1")
    jwk = JWT::JWK.new(key, "governance-key").export.merge(alg: "ES384", use: "sig")
    jwks = JSON.parse(JSON.generate({ keys: [jwk] }))
    payload = {
      "iss" => "https://governance.example",
      "aud" => "https://visa.example",
      "iat" => 1_000,
      "exp" => 1_060,
      "jti" => "11111111-1111-4111-8111-111111111111",
      "realm" => "app",
      "sub" => "cli_existing",
      "scope" => "all_sessions",
      "actor" => "opr_operator",
      "reason" => "account_disabled",
    }
    header = { kid: "governance-key", typ: "governance-revocation+jwt" }
    token = JWT.encode(payload, key, "ES384", header)
    verifier = GovernanceRevocationCommandVerifier.new(
      issuer: payload.fetch("iss"), audience: payload.fetch("aud"), realm: "app",
      jwks_url: "https://governance.example/.well-known/jwks.json", fetcher: -> { jwks }, now: Time.at(1_000).utc,
    )

    assert_equal "existing", verifier.verify(token).principal_public_id

    [
      JWT.encode(payload, attacker_key, "ES384", header),
      JWT.encode(payload, key, "ES384", header.merge(typ: "JWT")),
      JWT.encode(payload, key, "ES384", header.merge(kid: "unknown")),
      JWT.encode(payload, key, "ES384", header.merge(jku: "https://attacker.example/keys")),
      JWT.encode(payload, key, "ES384", header.merge(crit: ["extra"])),
      JWT.encode(payload.merge("realm" => "org"), key, "ES384", header),
      JWT.encode(payload.merge("exp" => 995), key, "ES384", header),
      JWT.encode(payload.merge("aud" => "https://other.example"), key, "ES384", header),
      JWT.encode(payload, OpenSSL::Random.random_bytes(48), "HS384", header),
      JWT.encode(payload, nil, "none", header), nil, "", "a.b.c",
      # Documented claims fit below this bound; malformed envelopes cover its reachable byte neighbors.
      "x" * 8_191, "x" * 8_192, "x" * 8_193,
    ].each do |invalid|
      assert_raises(GovernanceRevocationCommandVerifier::Rejected) { verifier.verify(invalid) }
    end
  end

  def test_unavailable_malformed_oversized_duplicate_or_private_keysets_never_authorize
    key = OpenSSL::PKey::EC.generate("secp384r1")
    jwk = JWT::JWK.new(key, "governance-key").export.merge(alg: "ES384", use: "sig")
    jwk = JSON.parse(JSON.generate(jwk))
    payload = {
      "iss" => "https://governance.example",
      "aud" => "https://visa.example",
      "iat" => 1_000,
      "exp" => 1_060,
      "jti" => "11111111-1111-4111-8111-111111111111",
      "realm" => "app",
      "sub" => "cli_existing",
      "scope" => "all_sessions",
      "actor" => "opr_operator",
      "reason" => "account_disabled",
    }
    token = JWT.encode(payload, key, "ES384", { kid: "governance-key", typ: "governance-revocation+jwt" })
    [nil, {}, { "keys" => [] }, { "keys" => [jwk, jwk] }, { "keys" => [jwk.merge("d" => "private")] },
     { "keys" => [jwk.merge("crv" => "P-256")] }, { "keys" => [jwk.merge("use" => "enc")] },
     { "keys" => [jwk.merge("x" => "A" * 64, "y" => "A" * 64)] },
     { "keys" => 11.times.map { |i| jwk.merge("kid" => "key-#{i}") } },].each do |keyset|
      verifier = GovernanceRevocationCommandVerifier.new(
        issuer: payload.fetch("iss"), audience: payload.fetch("aud"), realm: "app",
        jwks_url: "https://governance.example/keys", fetcher: -> { keyset }, now: Time.at(1_000).utc,
      )

      assert_raises(GovernanceRevocationCommandVerifier::Unavailable) { verifier.verify(token) }
    end
    ["http://governance.example/keys", "https://user:password@governance.example/keys",
     "https://governance.example/keys#fragment",].each do |url|
      assert_raises(GovernanceRevocationCommandVerifier::ConfigurationError) do
        GovernanceRevocationCommandVerifier.new(
          issuer: payload.fetch("iss"), audience: payload.fetch("aud"), realm: "app",
          jwks_url: url, fetcher: -> { { "keys" => [jwk] } }, now: Time.at(1_000).utc,
        )
      end
    end
  end
end
