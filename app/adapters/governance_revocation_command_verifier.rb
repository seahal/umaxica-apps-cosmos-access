# frozen_string_literal: true

require "json"
require "jwt"
require "uri"

class GovernanceRevocationCommandVerifier
  class Rejected < StandardError; end

  class Unavailable < StandardError; end

  class ConfigurationError < StandardError; end

  TOKEN_TYPE = "governance-revocation+jwt"
  MAX_TOKEN_BYTES = 8_192
  MAX_JWKS_BYTES = 65_536
  MAX_JWKS_KEYS = 10
  HEADER_KEYS = %w(alg kid typ).freeze
  JWK_KEYS = %w(kty crv x y kid alg use key_ops).freeze

  def initialize(issuer:, audience:, realm:, jwks_url:, fetcher: nil, now: Time.current)
    @issuer = issuer
    @audience = audience
    @realm = realm
    @jwks_uri = URI.parse(jwks_url)
    @fetcher = fetcher
    @now = now
    issuer_uri = URI.parse(issuer)
    raise ConfigurationError, "Governance issuer must be a bounded HTTPS origin" unless issuer.is_a?(String) &&
      issuer.bytesize <= 255 && issuer_uri.is_a?(URI::HTTPS) && issuer_uri.host &&
      issuer_uri.path.empty? && !issuer_uri.userinfo && !issuer_uri.query && !issuer_uri.fragment
    raise ConfigurationError, "Governance JWKS requires an HTTPS endpoint without credentials or fragments" unless
      @jwks_uri.is_a?(URI::HTTPS) && @jwks_uri.host && !@jwks_uri.userinfo && !@jwks_uri.fragment
  rescue URI::InvalidURIError, TypeError
    raise ConfigurationError, "Governance JWKS endpoint is invalid"
  end

  public

  def verify(token)
    raise Rejected, "signed command is missing or malformed" unless token.is_a?(String) &&
      token.bytesize <= MAX_TOKEN_BYTES && token.match?(/\A[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\.[A-Za-z0-9_-]+\z/)

    _, header = JWT.decode(token, nil, false)
    raise Rejected, "command header is not supported" unless valid_header?(header)

    keyset = fetcher ? fetcher.call : fetch_jwks
    keys = validated_keys(keyset)
    selected = keys.find { |key| key.fetch("kid") == header.fetch("kid") }
    raise Rejected, "command signing key is unknown" unless selected

    key = public_key(selected)
    payload, = JWT.decode(
      token, key, true, algorithms: ["ES384"], verify_expiration: false, verify_not_before: false,
                        verify_iat: false, verify_jti: false,
    )
    GovernanceRevocationCommandValue.new(payload:, issuer:, audience:, realm:, now:)
  rescue JWT::DecodeError, OpenSSL::PKey::PKeyError, GovernanceRevocationCommandValue::Invalid
    raise Rejected, "signed command could not be authenticated"
  end

  private

  attr_reader :issuer, :audience, :realm, :jwks_uri, :fetcher, :now

  def valid_header?(header)
    header.is_a?(Hash) && header.keys.sort == HEADER_KEYS.sort && header["alg"] == "ES384" &&
      header["typ"] == TOKEN_TYPE && header["kid"].is_a?(String) &&
      header["kid"].match?(/\A[A-Za-z0-9_.-]{1,128}\z/)
  end

  def validated_keys(keyset)
    raise Unavailable, "Governance JWKS is malformed" unless keyset.is_a?(Hash) &&
      keyset.keys == ["keys"] && keyset["keys"].is_a?(Array)

    keys = keyset.fetch("keys")
    raise Unavailable, "Governance JWKS has an invalid key count" unless keys.length.between?(1, MAX_JWKS_KEYS)
    raise Unavailable, "Governance JWKS is oversized" if JSON.generate(keyset).bytesize > MAX_JWKS_BYTES
    raise Unavailable, "Governance JWKS contains an invalid public key" unless keys.all? { |key| valid_jwk?(key) }

    identifiers = keys.map { |key| key.fetch("kid") }
    raise Unavailable, "Governance JWKS contains ambiguous key identifiers" if identifiers.uniq!

    keys
  rescue JSON::GeneratorError, TypeError
    raise Unavailable, "Governance JWKS is malformed"
  end

  def valid_jwk?(key)
    key.is_a?(Hash) && (key.keys - JWK_KEYS).empty? && key["kty"] == "EC" && key["crv"] == "P-384" &&
      key["alg"] == "ES384" && key["use"] == "sig" &&
      key["kid"].is_a?(String) && key["kid"].match?(/\A[A-Za-z0-9_.-]{1,128}\z/) &&
      key["x"].is_a?(String) && key["x"].match?(/\A[A-Za-z0-9_-]{64}\z/) &&
      key["y"].is_a?(String) && key["y"].match?(/\A[A-Za-z0-9_-]{64}\z/) &&
      (!key.key?("key_ops") || key["key_ops"] == ["verify"])
  end

  def public_key(selected)
    JWT::JWK.import(selected).public_key
  rescue JWT::DecodeError, OpenSSL::PKey::PKeyError, OpenSSL::PKey::EC::Point::Error
    raise Unavailable, "Governance JWKS contains an invalid public key"
  end

  def fetch_jwks
    connection = OutboundHttp::Connection.build(
      url: jwks_uri, open_timeout: 1, read_timeout: 2, write_timeout: 2,
      require_https: true, require_public_address: true,
    )
    body = +""
    response =
      connection.get(jwks_uri) do |request|
        request.options.on_data =
          lambda do |chunk, _size|
            raise Unavailable, "Governance JWKS is oversized" if body.bytesize + chunk.bytesize > MAX_JWKS_BYTES

            body << chunk
          end
      end
    raise Unavailable, "Governance JWKS request failed" unless response.success?

    JSON.parse(body)
  rescue JSON::ParserError, OutboundHttp::Connection::InsecureEndpointError, *OutboundHttp::Connection::NETWORK_ERRORS
    raise Unavailable, "Governance JWKS request failed"
  end
end
