# typed: false
# frozen_string_literal: true

require "test_helper"

class JwtTemporalValidationTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "auth access enforces the fixed thirty second iat nbf and exp boundaries" do
    travel_to Time.utc(2026, 10, 22, 12) do
      now = Time.current.to_i
      payload = {
        "iss" => AuthenticationJwtConfiguration.issuer,
        "aud" => AuthenticationJwtConfiguration.audiences("client"),
        "exp" => now + 300,
        "iat" => now - 60,
        "nbf" => now - 60,
        "sub" => "temporal-subject",
        "sid" => "temporal-session",
        "client_id" => AuthenticationJwtConfiguration.client_id("client"),
        "jti" => "temporal-jti",
        "acr" => "aal1",
        "scope" => "openid domain:client",
      }
      cases = [
        ["iat", now + 29, true], ["iat", now + 30, true], ["iat", now + 31, false],
        ["nbf", now + 29, true], ["nbf", now + 30, true], ["nbf", now + 31, false],
        ["exp", now - 29, true], ["exp", now - 30, false], ["exp", now - 31, false],
      ]
      cases.each do |claim, value, accepted|
        token = JitSecurityJwtKeyring.encode(payload.merge(claim => value), typ: "at+jwt", issuer_id: "auth")
        result = SecurityJwtAuthAccessTokenCodec.decode(token, host: "audit.example", resource_type: "client")

        assert_equal accepted, result.present?, "#{claim}=#{value - now}"
      end
    end
  end

  test "expired access decoding relaxes only expiration and preserves signature issuer audience and nbf checks" do
    travel_to Time.utc(2026, 10, 22, 12) do
      now = Time.current.to_i
      payload = {
        "iss" => AuthenticationJwtConfiguration.issuer,
        "aud" => AuthenticationJwtConfiguration.audiences("client"),
        "exp" => now + 300,
        "iat" => now - 60,
        "nbf" => now - 60,
        "sub" => "temporal-subject",
        "sid" => "temporal-session",
        "client_id" => AuthenticationJwtConfiguration.client_id("client"),
        "jti" => "temporal-jti",
        "acr" => "aal1",
        "scope" => "openid domain:client",
      }
      payload["exp"] = now - 120
      payload["iat"] = payload["nbf"] = now - 180
      token = JitSecurityJwtKeyring.encode(payload, typ: "at+jwt", issuer_id: "auth")

      assert_nil SecurityJwtAuthAccessTokenCodec.decode(token, host: "audit.example", resource_type: "client")
      assert_equal payload, SecurityJwtAuthAccessTokenCodec.decode_allow_expired(
        token, host: "audit.example", resource_type: "client",
      )

      [
        payload.merge("iss" => "urn:other:auth"),
        payload.merge("aud" => ["other-audience"]),
        payload.merge("nbf" => now + 31),
        payload.merge("iat" => now + 31),
        payload.except("exp"),
      ].each do |invalid_payload|
        invalid = JitSecurityJwtKeyring.encode(invalid_payload, typ: "at+jwt", issuer_id: "auth")

        assert_nil SecurityJwtAuthAccessTokenCodec.decode_allow_expired(
          invalid, host: "audit.example", resource_type: "client",
        )
      end

      forged = JWT.encode(
        payload, OpenSSL::PKey::EC.generate("secp384r1"), "ES384",
        { typ: "at+jwt", kid: JitSecurityJwtKeyring.active_kid("auth") },
      )

      assert_nil SecurityJwtAuthAccessTokenCodec.decode_allow_expired(
        forged, host: "audit.example", resource_type: "client",
      )
    end
  end

  test "anonymous preference JWT uses the exact 400 day lifetime without nbf" do
    travel_to Time.utc(2026, 10, 22, 12) do
      host = Rails.configuration.x.boot_config.fetch(:hosts).auth_service.host
      issued_at = Time.current
      snapshot = SecurityJwtPreferenceTokenCodec::ANONYMOUS_PREFERENCE_VALUES.transform_values(&:first)
      token = PreferenceToken.encode(
        snapshot, host: host, preference_type: "AppPreference",
                  public_id: "temporal-preference", jti: "temporal-jti",
                  jwt_issuer_id: "preference_app", issued_at: issued_at,
      )

      payload, header = JWT.decode(token, nil, false)

      assert_equal issued_at.to_i, payload.fetch("iat")
      assert_equal issued_at.to_i + 400.days.to_i, payload.fetch("exp")
      assert_equal "app", payload.fetch("aud")
      assert_equal "JWT", header.fetch("typ")
      assert_not payload.key?("nbf")
      assert_predicate PreferenceToken.decode(token, host: host, jwt_issuer_id: "preference_app"), :present?
    end
  end


  test "client assertions enforce the fixed thirty second iat boundary" do
    travel_to Time.utc(2026, 10, 22, 12) do
      now = Time.current
      token_url = OidcIssuer.token_endpoint("client")
      [[29, true], [30, true], [31, false]].each do |offset, accepted|
        token = OidcClientAssertionJwt.issue(
          client_id: "core-app-jp", token_url: token_url, now: now + offset,
        )

        assert_equal accepted, OidcClientAssertionJwt.valid?(
          client_id: "core-app-jp", assertion: token, token_url: token_url, now: now,
        ), "iat=now+#{offset}"
      end
    end
  end
end
