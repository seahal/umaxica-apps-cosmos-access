# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::App::Apple::NotificationsControllerTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  rate_limit_counters!

  setup do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    https!
  end

  test "signed provider notifications report unavailable and invalid signatures remain unauthorized" do
    key = OpenSSL::PKey::RSA.generate(2048)
    attacker_key = OpenSSL::PKey::RSA.generate(2048)
    now = Time.current
    claims = {
      iss: "https://appleid.apple.com",
      aud: "apple-app",
      iat: now.to_i,
      jti: "apple-halt-jti",
      events: { type: "consent-revoked", sub: "apple-subject", event_time: now.to_i },
    }
    loader = ->(_) { { keys: [JWT::JWK.new(key.public_key, kid: "apple-key").export] } }
    factory =
      lambda do |jws:|
        ExternalAuthentication::AppleNotificationVerifier.new(
          jws: jws, audience: "apple-app", jwks_loader: loader, clock: -> { now },
        )
      end
    [[key, 503], [attacker_key, 401]].each do |signing_key, status|
      token = JWT.encode(claims, signing_key, "RS256", { kid: "apple-key" })
      ExternalAuthentication::AppleNotificationVerifier.stub(:from_credentials, factory) do
        post auth_app_apple_notifications_path, params: { payload: token }.to_json,
                                                headers: { "CONTENT_TYPE" => "application/json" }
      end

      assert_equal status, response.status
      assert_includes response.headers.fetch("Cache-Control"), "no-store"
      assert_nil response.headers["Location"]
    end
  end

  test "bounded JSON parsing rejects malformed missing and oversized payloads before verification" do
    called = false
    factory =
      lambda do |**|
        called = true
        raise ExternalAuthentication::AppleNotificationVerifier::VerificationError.new(:signature_or_claims_invalid)
      end
    ExternalAuthentication::AppleNotificationVerifier.stub(:from_credentials, factory) do
      ["{", "[]", "{}", '{"payload":null}', '{"payload":""}'].each do |body|
        post auth_app_apple_notifications_path, params: body, headers: { "CONTENT_TYPE" => "application/json" }

        assert_response :bad_request
        assert_not called
      end
      [32.kilobytes - 1, 32.kilobytes, 32.kilobytes + 1].each do |size|
        called = false
        body = { payload: "x" * (size - 14) }.to_json

        assert_equal size, body.bytesize
        post auth_app_apple_notifications_path, params: body, headers: { "CONTENT_TYPE" => "application/json" }

        assert_equal (size > 32.kilobytes) ? 413 : 401, response.status
        assert_equal size <= 32.kilobytes, called
      end
    end
    post auth_app_apple_notifications_path, params: "payload"

    assert_response :unsupported_media_type
  end

  test "provider verification configuration failures remain unavailable" do
    factory =
      lambda do |**|
        raise ExternalAuthentication::AppleNotificationVerifier::ConfigurationError, "configuration unavailable"
      end
    ExternalAuthentication::AppleNotificationVerifier.stub(:from_credentials, factory) do
      post auth_app_apple_notifications_path, params: { payload: "signed" }.to_json,
                                              headers: { "CONTENT_TYPE" => "application/json" }
    end

    assert_response :service_unavailable
  end

  test "provider requests retain the sixty per minute source IP limit" do
    factory =
      lambda do |**|
        raise ExternalAuthentication::AppleNotificationVerifier::ConfigurationError, "configuration unavailable"
      end
    ExternalAuthentication::AppleNotificationVerifier.stub(:from_credentials, factory) do
      61.times do |index|
        post auth_app_apple_notifications_path, params: { payload: "signed" }.to_json,
                                                headers: { "CONTENT_TYPE" => "application/json",
                                                           "REMOTE_ADDR" => "198.51.100.42", }

        assert_equal (index < 60) ? 503 : 429, response.status
      end
    end
  end
end
