# frozen_string_literal: true

require "test_helper"
require "base64"
require "jit_security_jwt_jwk"

module Jit
  module Security
    module Jwt
      class Ps256KeyPolicyTest < ActiveSupport::TestCase
        self.fixture_table_names = []

        test "exported first-party JWKs are public PS256 RSA verification keys" do
          private_key = OpenSSL::PKey::RSA.generate(3_072)
          public_jwk = JitSecurityJwtJwk.export_public(private_key, kid: "ps256-app-2026-a")

          assert_equal "RSA", public_jwk.fetch("kty")
          assert_equal "PS256", public_jwk.fetch("alg")
          assert_equal "sig", public_jwk.fetch("use")
          assert_equal "ps256-app-2026-a", public_jwk.fetch("kid")
          assert_empty JitSecurityJwtJwk::PRIVATE_FIELDS & public_jwk.keys
          assert_kind_of OpenSSL::PKey::RSA, JitSecurityJwtJwk.import_public_key(public_jwk)
        end

        test "accepts RSA modulus at and above 3072-bit floor and rejects the nearest lower bit length" do
          # Use exact-width public JWK moduli: OpenSSL key generation can return a neighboring width.
          [3_071, 3_072, 3_073].each do |modulus_bits|
            byte_count = (modulus_bits + 7) / 8
            leading_bits = modulus_bits - ((byte_count - 1) * 8)
            modulus_bytes = Array.new(byte_count, 0)
            modulus_bytes[0] = 1 << (leading_bits - 1)
            modulus_bytes[-1] |= 3
            modulus = Base64.urlsafe_encode64(modulus_bytes.pack("C*"), padding: false)
            public_jwk = {
              "kty" => "RSA",
              "kid" => "ps256-rsa-#{modulus_bits}",
              "alg" => "PS256",
              "use" => "sig",
              "n" => modulus,
              "e" => "AQAB",
            }

            if modulus_bits < JitSecurityJwtJwk::MIN_RSA_MODULUS_BITS
              error =
                assert_raises(JitSecurityJwtJwk::Error) do
                  JitSecurityJwtJwk.normalize_public(public_jwk)
                end

              assert_match(/at least 3072 bits/, error.message)
            else
              assert_equal "PS256", JitSecurityJwtJwk.normalize_public(public_jwk).fetch("alg")
            end
          end
        end

        test "ES384 EC keys are no longer first-party signing keys" do
          private_key = OpenSSL::PKey::EC.generate("secp384r1")
          public_jwk = JWT::JWK.new(private_key, kid: "legacy-es384").export.stringify_keys
            .except(*JitSecurityJwtJwk::PRIVATE_FIELDS).merge("alg" => "ES384", "use" => "sig")

          assert_raises(JitSecurityJwtJwk::Error) do
            JitSecurityJwtJwk.normalize_public(public_jwk)
          end
        end
      end
    end
  end
end
