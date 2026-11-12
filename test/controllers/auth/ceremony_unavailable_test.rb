# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthCeremonyUnavailableTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "new ceremonies fail explicitly before reading an account or creating a ceremony" do
    ["PUBLIC_AUTH_SERVICE_URL", "PUBLIC_AUTH_STAFF_URL"].each do |host_key|
      host! ENV.fetch(host_key)
      https!
      %w(/sign/in /sign/up /ceremony_bindings /verification /verification/setup/new).each do |path|
        get path

        assert_response :service_unavailable
        assert_equal "Service unavailable", response.body
        assert_includes response.headers.fetch("Cache-Control"), "no-store"
        assert_nil response.headers["Location"]
        assert_not response.headers["Set-Cookie"].to_s.match?(/(?:__Host-)?auth_sid=/)
      end
    end
  end

  test "direct provider requests and callbacks remain unavailable on their owning surface" do
    [
      ["PUBLIC_AUTH_SERVICE_URL", %w(google apple)],
      ["PUBLIC_AUTH_STAFF_URL", %w(entra)],
    ].each do |host_key, providers|
      host! ENV.fetch(host_key)
      https!
      providers.each do |provider|
        post "/social/#{provider}"

        assert_response :service_unavailable
        assert_equal "Service unavailable", response.body
        assert_nil response.headers["Location"]

        get "/social/#{provider}/callback", params: { code: "untrusted", state: "untrusted" }

        assert_response :service_unavailable
        assert_equal "Service unavailable", response.body
        assert_nil response.headers["Location"]
      end
    end
  end
  test "credential and ceremony continuations reject every supported HTTP action" do
    [
      ["PUBLIC_AUTH_SERVICE_URL", [
        [:get, "/sign/up/email/new"], [:post, "/sign/up/email"],
        [:get, "/sign/up/telephone/new"], [:post, "/sign/up/telephone"],
        [:get, "/sign/up/guard/apple"], [:get, "/sign/up/guard/google"],
        [:get, "/sign/up/guard/email"], [:get, "/sign/up/guard/telephone"],
        [:get, "/sign/in/email/new"], [:post, "/sign/in/email"],
        [:get, "/sign/in/email/edit"], [:patch, "/sign/in/email"], [:delete, "/sign/in/email"],
        [:get, "/sign/in/passkey/new"], [:post, "/sign/in/passkey/options"],
        [:post, "/sign/in/passkey/verification"], [:get, "/sign/in/secret/new"],
        [:post, "/sign/in/secret"], [:get, "/sign/in/check"],
        [:get, "/sign/in/challenge"], [:delete, "/sign/in/challenge"],
        [:get, "/sign/in/challenge/passkey/new"], [:post, "/sign/in/challenge/passkey"],
        [:post, "/social/google/session"], [:post, "/social/google/registration"],
        [:post, "/social/apple/session"], [:post, "/social/apple/registration"],
        [:post, "/social/link_completion"], [:get, "/social/failure"],
        [:post, "/web/v0/in/email/otp"],
        [:get, "/verification/totp/new"], [:post, "/verification/totp"],
        [:get, "/verification/emails/new"], [:post, "/verification/emails"],
        [:get, "/verification/emails/1/edit"], [:patch, "/verification/emails/1"],
        [:post, "/verification/emails/1/redelivery"],
        [:get, "/settings/totps/new"], [:post, "/settings/totps"],
        [:post, "/settings/totps/enrollment"], [:delete, "/settings/totps/enrollment"],
        [:get, "/settings/totps/handoff"], [:post, "/settings/totps/handoff"],
        [:get, "/settings/apple"], [:get, "/settings/apple/edit"],
        [:post, "/settings/apple"], [:delete, "/settings/apple"],
        [:get, "/settings/google"], [:get, "/settings/google/edit"],
        [:post, "/settings/google"], [:delete, "/settings/google"],
      ],],
      ["PUBLIC_AUTH_STAFF_URL", [
        [:get, "/sign/in/passkey/new"], [:post, "/sign/in/passkey/options"],
        [:post, "/sign/in/passkey/verification"], [:get, "/sign/in/check"],
        [:get, "/sign/in/emergency/passkey/new"], [:post, "/sign/in/emergency/passkey/options"],
        [:post, "/sign/in/emergency/passkey/verification"],
        [:get, "/social/entra/session/new"], [:post, "/social/entra/session"],
        [:get, "/social/entra/failure"],
      ],],
    ].each do |host_key, requests|
      host! ENV.fetch(host_key)
      https!
      requests.each do |verb, path|
        case verb
        when :get then get(path)
        when :post then post(path)
        when :patch then patch(path)
        when :delete then delete(path)
        else raise ArgumentError, "unsupported test request verb"
        end

        assert_equal 503, response.status, "#{host_key} #{verb} #{path}"
        assert_equal "Service unavailable", response.body
        assert_nil response.headers["Location"]
      end
    end
  end

  test "shared verification and continuation actions fail without consuming admission state" do
    ["PUBLIC_AUTH_SERVICE_URL", "PUBLIC_AUTH_STAFF_URL"].each do |host_key|
      host! ENV.fetch(host_key)
      https!
      %w(/sign/oidc/handoff /sign/in/sentry /sign/up/sentry /verification/handoff
         /verification/passkey/new /verification/registration/passkey/new
         /verification/registration/handoff).each do |path|
        get path

        assert_response :service_unavailable
      end
      %w(/sign/cancellation /verification/cancellation /verification/handoff /verification/passkey
         /verification/passkey/options /verification/registration/passkey
         /verification/registration/passkey/options /verification/registration/handoff).each do |path|
        post path

        assert_response :service_unavailable
      end
    end
  end

  test "sign-up verification checkpoints cannot create accounts or credentials" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    https!
    %w(apple google email telephone).each do |provider|
      %w(confirmation birthdate otp passkey secret).each do |checkpoint|
        next if %w(apple google).include?(provider) && %w(otp passkey secret).include?(checkpoint)
        next if provider == "email" && %w(confirmation passkey secret).include?(checkpoint)
        next if provider == "telephone" && checkpoint == "confirmation"

        path = "/sign/up/check/#{provider}/#{checkpoint}"
        get path

        assert_response :service_unavailable
        patch path

        assert_response :service_unavailable
        delete path

        assert_response :service_unavailable
      end
    end
    %w(/sign/up/check/email/otp /sign/up/check/telephone/otp
       /sign/up/check/telephone/passkey /sign/up/check/telephone/secret
       /sign/up/check/telephone/secret/reattempt /sign/switch).each do |path|
      post path

      assert_response :service_unavailable
    end
  end

  test "retired preference APIs expose no account preference reader or writer" do
    ["PUBLIC_AUTH_SERVICE_URL", "PUBLIC_AUTH_STAFF_URL"].each do |host_key|
      host! ENV.fetch(host_key)
      https!
      %w(/api/v0/preferences/theme /api/v0/preferences/cookie).each do |path|
        get path

        assert_response :not_found
        assert_nil response.headers["Location"]
        patch path, params: { theme: "dark", consent: "accepted" }

        assert_response :not_found
        assert_nil response.headers["Location"]
      end
    end
  end

  test "public JWKS remain available on both Auth surfaces" do
    ["PUBLIC_AUTH_SERVICE_URL", "PUBLIC_AUTH_STAFF_URL"].each do |host_key|
      host! ENV.fetch(host_key)
      https!
      get "/.well-known/jwks.json"

      assert_response :ok
      assert_predicate response.parsed_body.fetch("keys"), :present?
    end
  end

  test "unsafe unavailable requests retain Rails forgery protection" do
    original = Auth::App::UnavailableCeremoniesController.allow_forgery_protection
    Auth::App::UnavailableCeremoniesController.allow_forgery_protection = true
    host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
    https!
    post("/social/google", headers: { "Origin" => "https://attacker.example" })

    assert_response :unprocessable_content
    assert_not_equal "Service unavailable", response.body
  ensure
    Auth::App::UnavailableCeremoniesController.allow_forgery_protection = original
  end
end
