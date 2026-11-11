# frozen_string_literal: true

require "test_helper"

class AppRailsEdgeOwnershipContractTest < ActiveSupport::TestCase
  RAILS_OWNED = [
    [ENV.fetch("PUBLIC_AUTH_SERVICE_URL"), :get, "/sign/in", "auth/app/sign/ins", "show"],
    [ENV.fetch("PUBLIC_VISA_SERVICE_URL"), :get, "/oauth/authorize", "visa/app/oauth/authorizations", "show"],
    [ENV.fetch("PUBLIC_VISA_SERVICE_URL"), :post, "/oauth/token", "visa/app/oauth/tokens", "create"],
  ].freeze

  test "app route ownership stays with retained Auth and Visa endpoints" do
    mismatches =
      RAILS_OWNED.filter_map do |host, method, path, expected_controller, expected_action|
        route = Rails.application.routes.recognize_path("http://#{host}#{path}", method: method)
        next if route[:controller] == expected_controller && route[:action] == expected_action

        "#{method.upcase} #{host}#{path}: #{route[:controller]}##{route[:action]}"
      rescue ActionController::RoutingError => e
        "#{method.upcase} #{host}#{path}: #{e.class}"
      end

    assert_empty mismatches
  end

end
