# typed: false
# frozen_string_literal: true

require "base64"
require "json"
require "openssl"
require "jit_security_jwt_jwk"

module JitSecurityJwtKeyMaterial
  module_function

  MIN_RSA_MODULUS_BITS = JitSecurityJwtJwk::MIN_RSA_MODULUS_BITS

  Error = Class.new(StandardError)

  def parse_private_keyset(raw)
    return {} if raw.blank?

    parsed = JSON.parse(raw)
    raise Error, "must be a JSON object" unless parsed.is_a?(Hash)

    parsed.transform_values { |value| decode_private_key(value) }.compact
  rescue JSON::ParserError => e
    raise Error, "contains invalid JSON: #{e.class.name}"
  end

  def decode_private_key(value)
    return nil if value.blank?

    raw = value.to_s
    encoded_key = raw.start_with?("-----BEGIN") ? pem_private_key(raw) : Base64.strict_decode64(raw)
    key = OpenSSL::PKey.read(encoded_key)
    raise Error, "must be an RSA private key" unless key.is_a?(OpenSSL::PKey::RSA) && key.private?
    raise Error, "RSA private key modulus must be at least #{MIN_RSA_MODULUS_BITS} bits" unless
      key.n.num_bits >= MIN_RSA_MODULUS_BITS
    raise Error, "must use unencrypted PKCS#8 private key material" unless pkcs8_private_key?(encoded_key)

    key
  rescue OpenSSL::PKey::PKeyError, ArgumentError
    raise Error, "contains invalid RSA key material"
  end

  def pem_private_key(raw)
    match = raw.match(/\A-----BEGIN ([A-Z ]+)-----/)
    raise Error, "must use unencrypted PKCS#8 private key material" unless match&.captures&.first == "PRIVATE KEY"

    raw
  end
  private_class_method :pem_private_key

  def pkcs8_private_key?(encoded_key)
    der = encoded_key.include?("BEGIN") ? pem_body_der(encoded_key) : encoded_key
    root = OpenSSL::ASN1.decode(der)
    return false unless root.is_a?(OpenSSL::ASN1::Sequence)
    return false unless root.value.size == 3

    version, algorithm_identifier, private_key = root.value
    version.is_a?(OpenSSL::ASN1::Integer) && algorithm_identifier.is_a?(OpenSSL::ASN1::Sequence) &&
      private_key.is_a?(OpenSSL::ASN1::OctetString)
  rescue OpenSSL::ASN1::ASN1Error
    false
  end
  private_class_method :pkcs8_private_key?

  def pem_body_der(encoded_key)
    body = encoded_key.lines.reject { |line| line.start_with?("---") }.join
    Base64.decode64(body)
  end
  private_class_method :pem_body_der
end
