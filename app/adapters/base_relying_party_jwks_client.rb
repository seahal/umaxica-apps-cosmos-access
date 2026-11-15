# typed: false
# frozen_string_literal: true

# Reads the fixed Base RP verification keys used for browser-carried handoffs.
class BaseRelyingPartyJwksClient
  JWKS_URI_BY_SURFACE = {
    "app" => "https://www.umaxica.app/.well-known/jwks.json",
    "org" => "https://www.umaxica.org/.well-known/jwks.json",
  }.freeze
  private_constant :JWKS_URI_BY_SURFACE

  CACHE_TTL = 30.seconds
  NEGATIVE_CACHE_TTL = 5.seconds
  HTTP_OPEN_TIMEOUT = 1
  HTTP_READ_TIMEOUT = 2
  MAX_JWKS_BYTES = 64.kilobytes
  MAX_JWKS_KEYS = 10
  MAX_KID_LENGTH = 128
  KID_PATTERN = /\A[\x21-\x7E]{1,#{MAX_KID_LENGTH}}\z/o

  class JwksUnavailable < StandardError; end
  class UnknownKid < StandardError; end
  class InvalidKeySet < StandardError; end
  class JwksBodyTooLarge < StandardError; end

  def initialize(surface:, cache: Rails.cache, fetcher: nil)
    @jwks_uri = JWKS_URI_BY_SURFACE.fetch(surface.to_s) do
      raise ArgumentError, "unsupported Base RP JWKS surface"
    end
    @cache = cache
    @fetcher = fetcher || method(:fetch_jwks)
  end

  public

  def public_key_for(kid:)
    raise ArgumentError, "invalid Base RP JWKS key id" unless valid_kid?(kid)
    raise UnknownKid, "Base RP JWKS key id is negative cached" if negative_kid_cached?(kid)

    jwk = find_key(jwks_keys(force: false), kid)
    jwk ||= find_key(jwks_keys(force: true), kid)
    unless jwk
      @cache.write(negative_cache_key(kid), true, expires_in: NEGATIVE_CACHE_TTL)
      raise UnknownKid, "Base RP JWKS key id is not published"
    end

    JitSecurityJwtJwk.import_public_key(jwk)
  rescue JitSecurityJwtJwk::Error => e
    raise InvalidKeySet, "Base RP JWKS key is invalid: #{e.class.name}"
  end

  private

  attr_reader :jwks_uri, :cache, :fetcher

  def valid_kid?(kid)
    kid.is_a?(String) && kid.match?(KID_PATTERN)
  end

  def find_key(keys, kid)
    keys.find { |entry| entry.fetch("kid") == kid }
  end

  def jwks_keys(force:)
    cached_jwks(force:).fetch("keys")
  end

  def cached_jwks(force:)
    cache.delete(cache_key) if force
    cached = cache.read(cache_key)
    return cached if cached && !force

    fresh = fetcher.call(jwks_uri)
    fresh = validate_jwks(fresh)
    cache.write(cache_key, fresh, expires_in: CACHE_TTL)
    fresh
  rescue JwksUnavailable, InvalidKeySet
    raise
  rescue JSON::ParserError, URI::InvalidURIError, *OutboundHttp::Connection::NETWORK_ERRORS => e
    raise JwksUnavailable, "Base RP JWKS fetch failed: #{e.class.name}"
  end

  def validate_jwks(document)
    raise InvalidKeySet, "Base RP JWKS document must be an object" unless document.is_a?(Hash)

    entries = document.stringify_keys["keys"]
    unless entries.is_a?(Array) && entries.any? && entries.size <= MAX_JWKS_KEYS
      raise InvalidKeySet, "Base RP JWKS key count is outside 1..#{MAX_JWKS_KEYS}"
    end

    seen_kids = Set.new
    keys = entries.filter_map do |entry|
      raise InvalidKeySet, "Base RP JWKS entry must be an object" unless entry.is_a?(Hash)

      source = entry.stringify_keys
      kid = source["kid"]
      unless valid_kid?(kid) && seen_kids.add?(kid)
        raise InvalidKeySet, "Base RP JWKS key id is invalid or duplicated"
      end
      if JitSecurityJwtJwk::PRIVATE_FIELDS.any? { |field| source.key?(field) }
        raise InvalidKeySet, "Base RP JWKS must not publish private key material"
      end

      case source["use"]
      when "enc"
        next
      when "sig"
        # This client verifies signed responses. Encryption keys have a separate consumer.
      else
        raise InvalidKeySet, "Base RP JWKS key use is unsupported"
      end

      if source.key?("key_ops") && source["key_ops"] != ["verify"]
        raise InvalidKeySet, "Base RP JWKS key operations must be verification-only"
      end

      JitSecurityJwtJwk.normalize_public(source)
    rescue JitSecurityJwtJwk::Error => e
      raise InvalidKeySet, "Base RP JWKS public signing key is invalid: #{e.class.name}"
    end

    raise InvalidKeySet, "Base RP JWKS does not contain a signing key" if keys.empty?

    { "keys" => keys }
  end

  def fetch_jwks(uri_string)
    uri = URI.parse(uri_string)
    raise JwksUnavailable, "Base RP JWKS endpoint must use HTTPS" unless uri.is_a?(URI::HTTPS)

    connection = OutboundHttp::Connection.build(
      url: uri,
      open_timeout: HTTP_OPEN_TIMEOUT,
      read_timeout: HTTP_READ_TIMEOUT,
      require_https: true,
    )
    body = +""
    response = connection.get(uri) do |request|
      request.options.on_data = lambda do |chunk, received_bytes, _environment|
        raise JwksBodyTooLarge if received_bytes > MAX_JWKS_BYTES

        body << chunk
      end
    end
    raise JwksUnavailable, "Base RP JWKS endpoint returned an unsuccessful response" unless response.success?

    if body.empty?
      body = response.body.to_s
      raise JwksBodyTooLarge if body.bytesize > MAX_JWKS_BYTES
    end

    JSON.parse(body)
  rescue JwksBodyTooLarge
    raise JwksUnavailable, "Base RP JWKS response exceeded its size limit"
  rescue JSON::ParserError, URI::InvalidURIError, *OutboundHttp::Connection::NETWORK_ERRORS => e
    raise JwksUnavailable, "Base RP JWKS fetch failed: #{e.class.name}"
  end

  def cache_key
    "oidc:base_rp_jwks:#{Digest::SHA256.hexdigest(jwks_uri)}"
  end

  def negative_cache_key(kid)
    "oidc:base_rp_jwks:negative:#{Digest::SHA256.hexdigest("#{jwks_uri}:#{kid}")}"
  end

  def negative_kid_cached?(kid)
    cache.read(negative_cache_key(kid)).present?
  end
end
