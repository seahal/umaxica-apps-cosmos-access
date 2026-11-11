# frozen_string_literal: true

require "test_helper"

class AccessPersonalResponseCacheControlBoundaryTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "personal responses override downstream caching for success redirects client errors and server errors" do
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    response_headers = { "Cache-Control" => "public, max-age=3600", "content-type" => "text/plain" }.freeze
    response_body = ["response"]
    downstream_status = 200
    boundary = AccessPersonalResponseCacheControl.new(
      ->(_) { [downstream_status, response_headers, response_body] }, hosts: hosts,
    )
    env = Rack::MockRequest.env_for("https://#{hosts.auth_service.host}/settings")

    [200, 204, 302, 303, 400, 401, 403, 422, 429, 500, 503].each do |status|
      downstream_status = status
      actual_status, headers, body = boundary.call(env)

      assert_equal status, actual_status
      assert_equal "private, no-store", headers.fetch("cache-control")
      assert_not headers.key?("Cache-Control")
      assert_equal "text/plain", headers.fetch("content-type")
      assert_same response_body, body
      assert_equal "public, max-age=3600", response_headers.fetch("Cache-Control")
    end
  end

  test "personal path formats and accepted trailing slashes retain the same policy" do
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    boundary = AccessPersonalResponseCacheControl.new(->(_) { [422, {}, []] }, hosts: hosts)
    [
      [hosts.auth_service.host, "/settings.json"],
      [hosts.auth_service.host, "/settings/apple/edit"],
      [hosts.auth_service.host, "/social/google/callback/"],
      [hosts.auth_service.host, "/social/apple/callback.json"],
      [hosts.auth_staff.host, "/social/entra/callback/"],
      [hosts.visa_service.host, "/oauth/authorize.json"],
      [hosts.visa_staff.host, "/oauth/authorize/"],
      [hosts.visa_service.host, "/oauth//authorize"],
      [hosts.auth_service.host, "/social//google/callback"],
    ].each do |host, path|
      _, headers, = boundary.call(Rack::MockRequest.env_for("https://#{host}#{path}"))

      assert_equal "private, no-store", headers.fetch("cache-control"), path
    end
  end

  test "public paths other surfaces and adjacent path names preserve the downstream response" do
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    headers = { "cache-control" => "public, max-age=300" }.freeze
    boundary = AccessPersonalResponseCacheControl.new(->(_) { [200, headers, []] }, hosts: hosts)
    [
      [hosts.auth_service.host, "/.well-known/jwks.json"],
      [hosts.auth_service.host, "/.well-known//jwks.json"],
      [hosts.auth_service.host, "/sitemap.xml"],
      [hosts.auth_service.host, "/robots.txt"],
      [hosts.auth_service.host, "/settings-extra"],
      [hosts.auth_service.host, "/social/google/callback-extra"],
      [hosts.auth_staff.host, "/settings"],
      [hosts.auth_staff.host, "/social/google/callback"],
      [hosts.visa_service.host, "/.well-known/openid-configuration"],
      [hosts.visa_service.host, "/health"],
      [hosts.visa_service.host, "/revision"],
      [hosts.visa_service.host, "/oauth/authorize-extra"],
      [hosts.auth_service.host, "/oauth/authorize"],
      [hosts.visa_service.host, "/social/apple/callback"],
      ["other.example", "/settings"],
    ].each do |host, path|
      _, returned_headers, = boundary.call(Rack::MockRequest.env_for("https://#{host}#{path}"))

      assert_same headers, returned_headers, path
    end
  end

  test "the original personal path survives downstream framework status-path rewriting" do
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    boundary = AccessPersonalResponseCacheControl.new(
      lambda { |env|
        env["PATH_INFO"] = "/422"
        [422, {}, []]
      }, hosts: hosts,
    )
    env = Rack::MockRequest.env_for("https://#{hosts.visa_service.host}/oauth/authorize")

    status, headers, = boundary.call(env)

    assert_equal 422, status
    assert_equal "private, no-store", headers.fetch("cache-control")
  end

  test "cache policy follows the host after trusted forwarded-header filtering" do
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    response_headers = { "cache-control" => "public, max-age=300" }.freeze
    filtered = TrustedForwardedHeaders.new(
      ->(_) { [200, response_headers, []] }, trusted_proxies: [IPAddr.new("127.0.0.0/8")],
    )
    boundary = AccessPersonalResponseCacheControl.new(filtered, hosts: hosts)
    [
      ["other.example", hosts.auth_service.host, "198.51.100.10", false],
      ["other.example", hosts.auth_service.host, "127.0.0.1", true],
      [hosts.auth_service.host, "other.example", "198.51.100.10", true],
      [hosts.auth_service.host, "other.example", "127.0.0.1", false],
    ].each do |origin_host, forwarded_host, peer, personal|
      env = Rack::MockRequest.env_for(
        "https://#{origin_host}/settings",
        "HTTP_X_FORWARDED_HOST" => forwarded_host,
        "REMOTE_ADDR" => peer,
      )

      _, headers, = boundary.call(env)

      if personal
        assert_equal "private, no-store", headers.fetch("cache-control")
      else
        assert_same response_headers, headers
      end
    end
  end
end
