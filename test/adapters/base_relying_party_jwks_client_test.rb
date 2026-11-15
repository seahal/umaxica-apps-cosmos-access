# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseRelyingPartyJwksClientTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  def setup
    @key = OpenSSL::PKey::RSA.generate(3072)
    @cache = ActiveSupport::Cache::MemoryStore.new
  end

  test "fetches the fixed App Base JWKS and accepts a published PS256 RSA key at the size boundary" do
    keyset = { "keys" => [JitSecurityJwtJwk.export_public(@key, kid: "base-app-test")] }
    requested_uri = nil
    client = BaseRelyingPartyJwksClient.new(
      surface: "app",
      cache: @cache,
      fetcher: ->(uri) { requested_uri = uri.to_s; keyset },
    )

    public_key = client.public_key_for(kid: "base-app-test")

    assert_equal "https://www.umaxica.app/.well-known/jwks.json", requested_uri
    assert_instance_of OpenSSL::PKey::RSA, public_key
    assert_equal 3072, public_key.n.num_bits
  end

  test "fetches the fixed Org Base JWKS for the operator realm" do
    keyset = { "keys" => [JitSecurityJwtJwk.export_public(@key, kid: "base-org-test")] }
    requested_uri = nil
    client = BaseRelyingPartyJwksClient.new(
      surface: "org",
      cache: @cache,
      fetcher: ->(uri) { requested_uri = uri.to_s; keyset },
    )

    client.public_key_for(kid: "base-org-test")

    assert_equal "https://www.umaxica.org/.well-known/jwks.json", requested_uri
  end

  test "an unknown key id refetches once and never falls back to another key" do
    keyset = { "keys" => [JitSecurityJwtJwk.export_public(@key, kid: "base-app-known")] }
    fetch_count = 0
    client = BaseRelyingPartyJwksClient.new(
      surface: "app",
      cache: @cache,
      fetcher: ->(_uri) { fetch_count += 1; keyset },
    )

    2.times do
      assert_raises(BaseRelyingPartyJwksClient::UnknownKid) do
        client.public_key_for(kid: "not-published")
      end
    end

    assert_equal 2, fetch_count
  end

  test "rejects a signing key below 3072 bits" do
    short_key = OpenSSL::PKey::RSA.generate(2048)
    short_jwk = JWT::JWK.new(short_key, kid: "too-small").export.stringify_keys
      .except(*JitSecurityJwtJwk::PRIVATE_FIELDS).merge("alg" => "PS256", "use" => "sig")
    keyset = { "keys" => [short_jwk] }
    client = BaseRelyingPartyJwksClient.new(
      surface: "app", cache: @cache, fetcher: ->(_uri) { keyset },
    )

    assert_raises(BaseRelyingPartyJwksClient::InvalidKeySet) do
      client.public_key_for(kid: "too-small")
    end
  end

  test "ignores an encryption key and rejects unsupported signature algorithms" do
    valid_jwk = JitSecurityJwtJwk.export_public(@key, kid: "base-key")
    enc_key = OpenSSL::PKey::RSA.generate(2048)
    enc_jwk = JWT::JWK.new(enc_key, kid: "base-enc-key").export.stringify_keys
      .except(*JitSecurityJwtJwk::PRIVATE_FIELDS).merge("alg" => "RSA-OAEP-256", "use" => "enc")
    client = BaseRelyingPartyJwksClient.new(
      surface: "app", cache: ActiveSupport::Cache::MemoryStore.new,
      fetcher: ->(_uri) { { "keys" => [enc_jwk, valid_jwk] } },
    )

    assert_equal 3072, client.public_key_for(kid: "base-key").n.num_bits
    assert_raises(BaseRelyingPartyJwksClient::UnknownKid) { client.public_key_for(kid: "base-enc-key") }

    wrong_algorithm = valid_jwk.merge("alg" => "ES384")
    invalid_client = BaseRelyingPartyJwksClient.new(
      surface: "app", cache: ActiveSupport::Cache::MemoryStore.new,
      fetcher: ->(_uri) { { "keys" => [wrong_algorithm] } },
    )

    assert_raises(BaseRelyingPartyJwksClient::InvalidKeySet) do
      invalid_client.public_key_for(kid: "base-key")
    end
  end

  test "rejects a key set with no PS256 signing key" do
    valid_jwk = JitSecurityJwtJwk.export_public(@key, kid: "base-enc-only")
    enc_jwk = valid_jwk.merge("alg" => "RSA-OAEP-256", "use" => "enc")
    client = BaseRelyingPartyJwksClient.new(
      surface: "app", cache: @cache, fetcher: ->(_uri) { { "keys" => [enc_jwk] } },
    )

    assert_raises(BaseRelyingPartyJwksClient::InvalidKeySet) do
      client.public_key_for(kid: "base-enc-only")
    end
  end

  test "rejects private key material even on an unused encryption entry" do
    private_jwk = JWT::JWK.new(@key, kid: "base-enc-private").export.stringify_keys
      .merge("alg" => "RSA-OAEP-256", "use" => "enc")
    client = BaseRelyingPartyJwksClient.new(
      surface: "app", cache: @cache, fetcher: ->(_uri) { { "keys" => [private_jwk] } },
    )

    assert_raises(BaseRelyingPartyJwksClient::InvalidKeySet) do
      client.public_key_for(kid: "base-enc-private")
    end
  end

  test "fetches the JWKS through the fixed HTTPS outbound connection" do
    uri = "https://www.umaxica.app/.well-known/jwks.json"
    keyset = JSON.generate(keys: [JitSecurityJwtJwk.export_public(@key, kid: "base-app-http")])
    stubs = Faraday::Adapter::Test::Stubs.new do |stub|
      stub.get(uri) { [200, { "Content-Type" => "application/json" }, keyset] }
    end
    connection = Faraday.new do |builder|
      builder.adapter(:test, stubs)
    end

    TestSupport::OutboundHttpGuard.allow do
      OutboundHttp::Connection.stub(:build, connection) do
        client = BaseRelyingPartyJwksClient.new(
          surface: "app", cache: @cache,
        )

        assert_equal 3072, client.public_key_for(kid: "base-app-http").n.num_bits
      end
    end

    stubs.verify_stubbed_calls
  end

  test "rejects an unknown surface before fetching a peer key" do
    fetch_count = 0
    assert_raises(ArgumentError) do
      BaseRelyingPartyJwksClient.new(
        surface: "com", cache: @cache, fetcher: ->(_uri) { fetch_count += 1; { "keys" => [] } },
      )
    end

    assert_equal 0, fetch_count
  end
end
