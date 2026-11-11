# typed: false
# frozen_string_literal: true

require "test_helper"

class PublicRobotsRoutingTest < ActionDispatch::IntegrationTest
  test "Auth owns robots and sitemap helpers on both credential hosts" do
    assert_public_file_helpers(
      robots: %i(auth_app_robots_path auth_org_robots_path),
      sitemaps: %i(auth_app_sitemap_path auth_org_sitemap_path),
    )
  end

  test "Visa owns robots helpers on both OP hosts" do
    assert_public_file_helpers(
      robots: %i(visa_app_robots_path visa_org_robots_path),
      sitemaps: [],
    )
  end

  test "retired RP and draw hosts have no public file route helpers" do
    %i(
      base_com_robots_path
      core_app_robots_path core_org_robots_path warp_app_robots_path warp_org_robots_path
      core_app_sitemap_path warp_app_sitemap_path
    ).each do |helper|
      assert_not_respond_to self, helper
    end
  end

  test "public file endpoints respond from their retained hosts" do
    endpoints = [
      [method(:auth_app_robots_path), ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), "robots", "User-agent: *\nDisallow:\n"],
      [method(:auth_org_robots_path), ENV.fetch("PUBLIC_AUTH_STAFF_URL"), "robots", "User-agent: *\nDisallow:\n"],
      [method(:visa_app_robots_path), ENV.fetch("PUBLIC_VISA_SERVICE_URL"), "robots", "User-agent: *\nDisallow: /\n"],
      [method(:visa_org_robots_path), ENV.fetch("PUBLIC_VISA_STAFF_URL"), "robots", "User-agent: *\nDisallow: /\n"],
      [method(:auth_app_sitemap_path), ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), "sitemap", nil],
      [method(:auth_org_sitemap_path), ENV.fetch("PUBLIC_AUTH_STAFF_URL"), "sitemap", nil],
    ]

    endpoints.each do |helper, host, kind, robots_body|
      host! host
      get helper.call, headers: browser_headers

      assert_response :success
      assert_not_predicate response, :redirect?
      if kind == "robots"
        assert_equal "text/plain; charset=utf-8", response.content_type
        assert_equal robots_body, response.body, helper.name
      else
        assert_equal "application/xml; charset=utf-8", response.content_type
      end
    end
  end

  private

  def assert_public_file_helpers(robots:, sitemaps:)
    robots.each do |helper|
      assert_respond_to self, helper
      assert_equal "/robots.txt", public_send(helper)
    end

    sitemaps.each do |helper|
      assert_respond_to self, helper
      assert_equal "/sitemap.xml", public_send(helper)
    end
  end

  def browser_headers
    { "Client-Agent" => "Mozilla/5.0" }
  end
end
