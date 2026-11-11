# typed: false
# frozen_string_literal: true

require "test_helper"

# Published static GET routes must reach an HTTP boundary without an unhandled exception on the host
# they are published for. Each route is requested on the first host its own host constraint lists,
# so a 404 means the route no longer answers on its host rather than that it was sent elsewhere.
class StaticGetRouteResponseTest < ActionDispatch::IntegrationTest
  SKIP = %r{/(callback|oauth|social|action_mailbox|conductor|historical_location)\b}

  test "static GET routes answer on their own host without a server error or a routing miss" do
    routes = static_get_routes_by_host

    assert_predicate routes, :any?, "no host-constrained static GET route was discovered"

    failures = []
    routes.each do |host, paths|
      host! host
      paths.each do |path|
        get(path)
        failures << "GET #{path}: #{response.status}" if response.server_error? || response.not_found?
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
      .map { |route| [route.constraints[:host].first, route.path.spec.to_s.sub(/\(\.:format\)\z/, "")] }
      .reject { |_host, path| path.include?(":") || path.include?("*") || path.include?("(") || path.match?(SKIP) }
      .uniq
      .group_by(&:first)
      .transform_values { |pairs| pairs.map(&:last) }
  end
end
