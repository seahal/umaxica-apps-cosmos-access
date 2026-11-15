# typed: false
# frozen_string_literal: true

require "test_helper"

# Published static GET routes must reach their declared HTTP boundary on the host they are
# published for. Explicitly unavailable ceremony routes return 503; other routes must not return
# an unhandled server error or routing miss.
class StaticGetRouteResponseTest < ActionDispatch::IntegrationTest
  SKIP = %r{/(callback|oauth|social|action_mailbox|conductor|historical_location)\b}

  test "static GET routes answer on their own host without a server error or a routing miss" do
    routes = static_get_routes_by_host

    assert_predicate routes, :any?, "no host-constrained static GET route was discovered"

    failures = []
    routes.each do |host, paths|
      host! host
      paths.each do |path, controller|
        get(path)
        if controller.end_with?("unavailable_ceremonies")
          failures << "GET #{path}: expected 503, received #{response.status}" unless response.status == 503
        elsif response.server_error? || response.not_found?
          failures << "GET #{path}: #{response.status}"
        end
      rescue StandardError => e
        failures << "GET #{path}: #{e.class}: #{e.message}"
      end
    end

    assert_empty failures, failures.join("\n")
  end

  private

  def static_get_routes_by_host
    Rails.application.routes.routes
      .select { |route| route.verb == "GET" && route.constraints[:host].is_a?(Array) }
      .map do |route|
        [route.constraints[:host].first, route.path.spec.to_s.sub(/\(\.:format\)\z/, ""), route.defaults[:controller]]
      end
      .reject do |_host, path, _controller|
        path.include?(":") || path.include?("*") || path.include?("(") || path.match?(SKIP)
      end
      .uniq
      .group_by(&:first)
      .transform_values { |pairs| pairs.map { |_host, path, controller| [path, controller] } }
  end
end
