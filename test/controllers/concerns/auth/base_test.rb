# typed: false
# frozen_string_literal: true

require "test_helper"

module Auth
  class BaseTest < ActiveSupport::TestCase
    self.fixture_table_names = []

    test "Token class has JWT_ALGORITHM constant" do
      assert_equal "PS256", AuthenticationToken::JWT_ALGORITHM
    end

    test "Token.extract_subject returns nil for nil payload" do
      assert_nil AuthenticationToken.extract_subject(nil)
    end

    test "Token.extract_session_id returns nil for nil payload" do
      assert_nil AuthenticationToken.extract_session_id(nil)
    end

    test "Token.extract_jti returns nil for nil payload" do
      assert_nil AuthenticationToken.extract_jti(nil)
    end

    test "JwtConfiguration.issuer returns string" do
      issuer = AuthenticationJwtConfiguration.issuer

      assert_kind_of String, issuer
    end

    test "JwtConfiguration.audiences requires a resource type" do
      assert_raises(ArgumentError) { AuthenticationJwtConfiguration.audiences }
    end

    test "JwtConfiguration.leeway_seconds returns integer" do
      assert_kind_of Integer, AuthenticationJwtConfiguration.leeway_seconds
    end

    test "InvalidPolicyError is a StandardError" do
      assert_operator AuthenticationBase::InvalidPolicyError, :<, StandardError
    end

    test "SkipNotAllowedError is a StandardError" do
      assert_operator AuthenticationBase::SkipNotAllowedError, :<, StandardError
    end

    test "JwtConfiguration.issuer is the test-environment authorization-server identity" do
      assert_equal "urn:umaxica:test:auth", AuthenticationJwtConfiguration.issuer
    end

    test "JwtConfiguration.audiences requires distinct resource-specific env" do
      with_env(
        "AUTH_JWT_CLIENT_AUDIENCES" => "u1,u2",
        "AUTH_JWT_OPERATOR_AUDIENCES" => "o1",
      ) do
        assert_equal %w(u1 u2), AuthenticationJwtConfiguration.audiences("client")
        assert_equal %w(o1), AuthenticationJwtConfiguration.audiences("operator")
      end
    end

    test "JwtConfiguration.audiences rejects missing blank and overlapping values" do
      with_env("AUTH_JWT_CLIENT_AUDIENCES" => nil) do
        assert_raises(KeyError) { AuthenticationJwtConfiguration.audiences("client") }
      end
      with_env("AUTH_JWT_CLIENT_AUDIENCES" => "  ") do
        assert_raises(KeyError) { AuthenticationJwtConfiguration.audiences("client") }
      end
      with_env(
        "AUTH_JWT_CLIENT_AUDIENCES" => "shared",
        "AUTH_JWT_OPERATOR_AUDIENCES" => "shared,operator-only",
      ) do
        assert_raises(ArgumentError) { AuthenticationJwtConfiguration.audiences("client") }
      end
    end

    private

    def with_env(vars)
      original = vars.keys.index_with { |k| ENV[k] }
      vars.each { |k, v| ENV[k] = v }
      yield
    ensure
      original.each { |k, v| ENV[k] = v }
    end
  end
end
