# typed: false
# frozen_string_literal: true

require "jwt"
require "openssl"

module JitSecurityJwtJwk
  module_function

  ALGORITHM = "PS256"
  MIN_RSA_MODULUS_BITS = 3_072
  REQUIRED_PUBLIC_FIELDS = %w(kty kid alg use n e).freeze
  PRIVATE_FIELDS = %w(d p q dp dq qi oth k).freeze

  Error = Class.new(StandardError)

  def normalize_public(entry)
    jwk = normalized_entry(entry, REQUIRED_PUBLIC_FIELDS)
    validate_public!(jwk)
    jwk
  end

  def validate_public!(jwk)
    missing = REQUIRED_PUBLIC_FIELDS.reject { |field| jwk[field].present? }
    raise Error, "public JWK is missing #{missing.join(", ")}" if missing.present?
    raise Error, "public JWK alg must be #{ALGORITHM}" unless jwk["alg"] == ALGORITHM
    raise Error, "public JWK use must be sig" unless jwk["use"] == "sig"
    raise Error, "public JWK kty must be RSA" unless jwk["kty"] == "RSA"
    raise Error, "RSA public JWK modulus must be at least #{MIN_RSA_MODULUS_BITS} bits" unless
      rsa_modulus_bits(jwk) >= MIN_RSA_MODULUS_BITS

    true
  rescue JWT::JWKError, OpenSSL::PKey::PKeyError, ArgumentError
    raise Error, "public JWK contains invalid RSA key material"
  end

  def export_public(key, kid:)
    raise Error, "first-party signing key must be RSA" unless key.is_a?(OpenSSL::PKey::RSA)
    raise Error, "RSA private key modulus must be at least #{MIN_RSA_MODULUS_BITS} bits" unless
      key.n.num_bits >= MIN_RSA_MODULUS_BITS

    JWT::JWK.new(key, kid: kid).export.stringify_keys.except(*PRIVATE_FIELDS).merge(
      "alg" => ALGORITHM,
      "use" => "sig",
    )
  end

  def import_public_key(jwk)
    normalized = normalize_public(jwk)
    JWT::JWK.import(normalized.except("state")).public_key
  rescue JWT::JWKError, OpenSSL::PKey::PKeyError, ArgumentError => e
    raise Error, "contains invalid public JWK material: #{e.class.name}"
  end

  def rsa_modulus_bits(jwk)
    key = JWT::JWK.import(jwk.except("state")).public_key
    raise Error, "public JWK kty must be RSA" unless key.is_a?(OpenSSL::PKey::RSA)

    key.n.num_bits
  end
  private_class_method :rsa_modulus_bits

  def normalized_entry(entry, required_fields)
    raise Error, "entry must be a JSON object" unless entry.is_a?(Hash)

    source_hash = entry.stringify_keys
    if PRIVATE_FIELDS.any? { |field| source_hash.key?(field) }
      raise Error, "entry #{source_hash["kid"].inspect} contains private JWK material"
    end

    source_hash.slice(*(required_fields + ["state"]))
  end
  private_class_method :normalized_entry
end
