# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"
require "jit_security_jwt_jwk"

module Jit
  module Security
    module Jwt
      class JwkTest < ActiveSupport::TestCase
        self.fixture_table_names = []

        setup do
          @key = OpenSSL::PKey::RSA.generate(3_072)
          @public_jwk = JitSecurityJwtJwk.export_public(@key, kid: "kid-1")
        end

        test "exports public jwk without private material" do
          assert_equal "kid-1", @public_jwk.fetch("kid")
          assert_equal JitSecurityJwtJwk::ALGORITHM, @public_jwk.fetch("alg")
          assert_equal "sig", @public_jwk.fetch("use")
          assert_empty JitSecurityJwtJwk::PRIVATE_FIELDS & @public_jwk.keys
        end

        test "normalizes valid public jwk" do
          normalized = JitSecurityJwtJwk.normalize_public(@public_jwk.merge(extra: "ignored"))

          assert_equal @public_jwk, normalized
        end

        test "rejects public jwk with private material" do
          error =
            assert_raises(JitSecurityJwtJwk::Error) do
              JitSecurityJwtJwk.normalize_public(@public_jwk.merge("d" => "secret"))
            end

          assert_match(/private JWK material/, error.message)
        end

        test "rejects unexpected algorithm" do
          error =
            assert_raises(JitSecurityJwtJwk::Error) do
              JitSecurityJwtJwk.normalize_public(@public_jwk.merge("alg" => "HS256"))
            end

          assert_match(/alg must be PS256/, error.message)
        end

        test "rejects incomplete public jwk" do
          error =
            assert_raises(JitSecurityJwtJwk::Error) do
              JitSecurityJwtJwk.normalize_public(@public_jwk.except("n"))
            end

          assert_match(/missing n/, error.message)
        end

        test "imports valid public jwk material" do
          assert_kind_of OpenSSL::PKey::RSA, JitSecurityJwtJwk.import_public_key(@public_jwk)
        end

        test "rejects RSA JWKs labelled with non-PS256 algorithms" do
          %w(RS256 PS384 HS256).each do |algorithm|
            assert_raises(JitSecurityJwtJwk::Error, algorithm) do
              JitSecurityJwtJwk.normalize_public(@public_jwk.merge("alg" => algorithm))
            end
          end
        end

        test "rejects EC public JWKs for first-party verification" do
          ec_key = OpenSSL::PKey::EC.generate("secp384r1")
          ec_jwk = JWT::JWK.new(ec_key, kid: "legacy-es384").export.stringify_keys.except("d").merge(
            "alg" => "ES384",
            "use" => "sig",
          )

          assert_raises(JitSecurityJwtJwk::Error) { JitSecurityJwtJwk.normalize_public(ec_jwk) }
        end
      end
    end
  end
end
