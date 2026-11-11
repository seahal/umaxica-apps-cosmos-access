# typed: false
# frozen_string_literal: true

require "test_helper"

# public_robots_routing_test.rb covers the Auth and Visa surfaces.
# The App and Org surfaces answer /robots.txt from their own
# controllers, and each of those is a separate crawl directive: a surface that
# silently 404s here is one a crawler is free to index. The corporate auth host no
# longer serves any page, so it has no crawl directive to publish.
class SurfaceRobotsEndpointTest < ActionDispatch::IntegrationTest
  SURFACE_HOSTS = {
    "visa_app" => "PUBLIC_VISA_SERVICE_URL",
    "visa_org" => "PUBLIC_VISA_STAFF_URL",
    "auth_org" => "PUBLIC_AUTH_STAFF_URL",
  }.freeze

  SURFACE_HOSTS.each do |prefix, env_name|
    test "#{prefix} serves robots.txt as plain text from its own host" do
      host! ENV.fetch(env_name)

      get public_send("#{prefix}_robots_path"), headers: { "Client-Agent" => "Mozilla/5.0" }

      assert_response :success
      assert_equal "text/plain; charset=utf-8", response.content_type
      expected_disallow = prefix.start_with?("visa_") ? "Disallow: /\n" : "Disallow:\n"

      assert_equal "User-agent: *\n#{expected_disallow}", response.body
    end
  end
end
