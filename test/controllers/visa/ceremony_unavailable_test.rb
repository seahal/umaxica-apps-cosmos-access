# typed: false
# frozen_string_literal: true

require "test_helper"

class VisaCeremonyUnavailableTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "authorization start validates locally while result and cancellation remain unavailable" do
    ["PUBLIC_VISA_SERVICE_URL", "PUBLIC_VISA_STAFF_URL"].each do |host_key|
      host! ENV.fetch(host_key)
      https!
      get "/oauth/authorize", params: { client_id: "untrusted", request_uri: "untrusted" }

      assert_response :bad_request
      assert_equal "invalid_request", response.parsed_body.fetch("error")
      assert_nil response.location
      assert_equal "no-referrer", response.headers["Referrer-Policy"]
      assert_includes response.headers.fetch("Cache-Control"), "no-store"

      %w(/oidc/result /oidc/cancellation).each do |path|
        get path, params: { client_id: "untrusted", request_uri: "untrusted" }

        assert_response :service_unavailable
        assert_equal "Service unavailable", response.body
        assert_nil response.headers["Location"]
        assert_includes response.headers.fetch("Cache-Control"), "no-store"
        assert_nil response.headers["Set-Cookie"]
      end
      post "/oauth/authorize", params: { client_id: "untrusted", consent: "accept" }

      assert_response :bad_request
      assert_equal "invalid_request", response.parsed_body.fetch("error")
      assert_nil response.location
      assert_equal "no-referrer", response.headers["Referrer-Policy"]
    end
    host! ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    get "/oidc/switch"

    assert_response :service_unavailable
  end

  test "browser admission confirmation and session limit continuations remain unavailable" do
    ["PUBLIC_VISA_SERVICE_URL", "PUBLIC_VISA_STAFF_URL"].each do |host_key|
      host! ENV.fetch(host_key)
      https!
      get "/ceremony_bindings/untrusted/confirmation"

      assert_response :service_unavailable
      get "/sign/in/limitation"

      assert_response :service_unavailable
      post "/sign/in/limitation"

      assert_response :service_unavailable
      patch "/sign/in/limitation"

      assert_response :service_unavailable
      delete "/sign/in/limitation"

      assert_response :service_unavailable
      assert_nil response.headers["Location"]
    end
  end

  test "Auth App and Org sign-in sentries remain explicitly unavailable" do
    ["PUBLIC_AUTH_SERVICE_URL", "PUBLIC_AUTH_STAFF_URL"].each do |host_key|
      host! ENV.fetch(host_key)
      https!
      get "/sign/in/sentry", params: { entry_ref: "untrusted", ri: "jp" }

      assert_response :service_unavailable
      assert_equal "Service unavailable", response.body
      assert_nil response.location
      assert_nil response.headers["Set-Cookie"]
      assert_equal "no-referrer", response.headers["Referrer-Policy"]
    end
  end

  test "Visa discovery and JWKS remain public in both realms" do
    ["PUBLIC_VISA_SERVICE_URL", "PUBLIC_VISA_STAFF_URL"].each do |host_key|
      host! ENV.fetch(host_key)
      https!
      get "/.well-known/openid-configuration"

      assert_response :ok
      assert_predicate response.parsed_body.fetch("issuer"), :present?
      get "/.well-known/jwks.json"

      assert_response :ok
      assert_predicate response.parsed_body.fetch("keys"), :present?
    end
  end

  test "unsafe Visa refusal retains the Rails origin and CSRF boundary" do
    original = Visa::Org::Oauth::AuthorizationsController.allow_forgery_protection
    Visa::Org::Oauth::AuthorizationsController.allow_forgery_protection = true
    host!(ENV.fetch("PUBLIC_VISA_STAFF_URL"))
    https!
    post("/oauth/authorize", headers: { "Origin" => "https://attacker.example" })

    assert_response :unprocessable_content
    assert_not_equal "Service unavailable", response.body
  ensure
    Visa::Org::Oauth::AuthorizationsController.allow_forgery_protection = original
  end
end
