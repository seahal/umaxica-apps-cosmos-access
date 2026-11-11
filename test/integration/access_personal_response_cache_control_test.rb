# frozen_string_literal: true

require "test_helper"

class AccessPersonalResponseCacheControlTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "unauthenticated settings responses remain uncacheable when admission stops before the action" do
    host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
    https!

    get "/settings", params: { ri: "jp" }

    assert_equal 404, response.status, "/settings"
    assert_equal "private, no-store", response.headers["Cache-Control"], "/settings"

    %w(/settings/apple /settings/apple/edit /settings/google /settings/google/edit /settings//apple).each do |path|
      get path, params: { ri: "jp" }

      assert_equal 400, response.status, path
      assert_equal "private, no-store", response.headers["Cache-Control"], path
    end
  end

  test "provider callback refusals including normalized paths are uncacheable in the owning Auth realm" do
    previous_test_mode = OmniAuth.config.test_mode
    previous_auth = OmniAuth.config.mock_auth.slice(:google, :apple, :entra)
    OmniAuth.config.test_mode = true
    %i(google apple entra).each { |provider| OmniAuth.config.mock_auth[provider] = :invalid_credentials }
    https!

    [
      [ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), "/social/google/callback"],
      [ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), "/social/apple/callback"],
      [ENV.fetch("PUBLIC_AUTH_STAFF_URL"), "/social/entra/callback"],
      [ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), "/social//google/callback"],
      [ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), "/social//apple/callback"],
      [ENV.fetch("PUBLIC_AUTH_STAFF_URL"), "/social//entra/callback"],
    ].each do |host, path|
      host!(host)
      get(path)

      assert_operator response.status, :>=, 300, path
      assert_operator response.status, :<, 500, path
      assert_equal "private, no-store", response.headers["Cache-Control"], path

      post(path)

      assert_operator response.status, :>=, 300, path
      assert_operator response.status, :<, 500, path
      assert_equal "private, no-store", response.headers["Cache-Control"], path
    end
  ensure
    %i(google apple entra).each { |provider| OmniAuth.config.mock_auth.delete(provider) }
    previous_auth.each { |provider, value| OmniAuth.config.mock_auth[provider] = value }
    OmniAuth.config.test_mode = previous_test_mode
  end

  test "a real authorization CSRF refusal retains no-store after framework exception rendering" do
    app_protection = Visa::App::Oauth::AuthorizationsController.allow_forgery_protection
    org_protection = Visa::Org::Oauth::AuthorizationsController.allow_forgery_protection
    Visa::App::Oauth::AuthorizationsController.allow_forgery_protection = true
    Visa::Org::Oauth::AuthorizationsController.allow_forgery_protection = true
    https!

    [ENV.fetch("PUBLIC_VISA_SERVICE_URL"), ENV.fetch("PUBLIC_VISA_STAFF_URL")].each do |host|
      host!(host)
      %w(/oauth/authorize /oauth//authorize).each do |path|
        post(path, params: { ceremony_action: "start" })

        assert_response :unprocessable_content
        assert_equal "private, no-store", response.headers["Cache-Control"]
      end
    end
  ensure
    Visa::App::Oauth::AuthorizationsController.allow_forgery_protection = app_protection
    Visa::Org::Oauth::AuthorizationsController.allow_forgery_protection = org_protection
  end

  test "public metadata is outside the personal response cache boundary" do
    https!
    [ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
     ENV.fetch("PUBLIC_VISA_SERVICE_URL"), ENV.fetch("PUBLIC_VISA_STAFF_URL"),].each do |host|
      host!(host)
      get "/.well-known/jwks.json"

      assert_response :success
      assert_not_includes response.headers["Cache-Control"].to_s, "no-store"
    end

    [ENV.fetch("PUBLIC_VISA_SERVICE_URL"), ENV.fetch("PUBLIC_VISA_STAFF_URL")].each do |host|
      host!(host)
      get "/.well-known/openid-configuration"

      assert_response :success
      assert_not_equal "private, no-store", response.headers["Cache-Control"]
    end
  end
end
