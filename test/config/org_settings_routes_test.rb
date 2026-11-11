# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthAppSettingsRoutesTest < ActiveSupport::TestCase
  test "Auth app removes the settings dashboard and keeps social link entry routes" do
    host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("https://#{host}/settings", method: :get)
    end

    [
      ["/settings/apple", "auth/app/settings/apples"],
      ["/settings/google", "auth/app/settings/googles"],
    ].each do |path, controller|
      route = Rails.application.routes.recognize_path("https://#{host}#{path}", method: :get)

      assert_equal controller, route.fetch(:controller)
      assert_equal "show", route.fetch(:action)
    end
  end
end
