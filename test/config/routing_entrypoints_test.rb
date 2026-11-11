# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class RoutingEntrypointsTest < ActiveSupport::TestCase
  test "global routing entrypoints are loaded" do
    assert_nothing_raised { Rails.application.reload_routes! }

    preference_route = Rails.application.routes.recognize_path(
      "http://auth.app.localhost/api/v0/preferences/theme",
      method: :get,
    )

    assert_equal "auth/app/api/v0/preferences/themes", preference_route[:controller]
    assert_equal "show", preference_route[:action]

    root_route = Rails.application.routes.recognize_path("http://unregistered.invalid/")

    assert_equal "unknown_hosts", root_route[:controller]
    assert_equal "show", root_route[:action]
  end

  test "Turbo Native history routes are not exposed" do
    route_names = Rails.application.routes.named_routes.names

    assert_empty route_names & %w(
      turbo_recede_historical_location
      turbo_resume_historical_location
      turbo_refresh_historical_location
    )
  end
end
