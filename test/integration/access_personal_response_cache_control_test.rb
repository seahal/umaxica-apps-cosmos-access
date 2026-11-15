# frozen_string_literal: true

require "test_helper"

class AccessPersonalResponseCacheControlTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "unavailable Auth settings routes remain uncacheable" do
    host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
    https!

    get "/settings", params: { ri: "jp" }

    assert_equal 404, response.status, "/settings"
    assert_equal "private, no-store", response.headers["Cache-Control"], "/settings"

    %w(/settings/apple /settings/apple/edit /settings/google /settings/google/edit).each do |path|
      get path, params: { ri: "jp" }

      assert_response :service_unavailable, path
      assert_equal "private, no-store", response.headers["Cache-Control"], path
    end

    get "/settings//apple", params: { ri: "jp" }

    assert_response :service_unavailable, "/settings//apple"
    assert_equal "private, no-store", response.headers["Cache-Control"], "/settings//apple"
  end

  test "provider callback entry points fail closed without caching in the owning Auth realm" do
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

      assert_response :service_unavailable, path
      assert_equal "private, no-store", response.headers["Cache-Control"], path
    end
  end

  test "JSON logout CSRF refusals remain private in both realms" do
    controllers = [Visa::App::Oidc::LogoutsController, Visa::Org::Oidc::LogoutsController]
    previous_protections = controllers.map(&:allow_forgery_protection)
    controllers.each { |controller| controller.allow_forgery_protection = true }
    https!

    [ENV.fetch("PUBLIC_VISA_SERVICE_URL"), ENV.fetch("PUBLIC_VISA_STAFF_URL")].each do |host|
      host!(host)
      post(
        "/oidc/logout", params: { ri: "jp" },
                        headers: { "Sec-Fetch-Site" => "cross-site" }, as: :json,
      )

      assert_response :forbidden
      assert_equal "no-store", response.headers["Cache-Control"]
    end
  ensure
    controllers.zip(previous_protections).each do |controller, protection|
      controller.allow_forgery_protection = protection
    end
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
