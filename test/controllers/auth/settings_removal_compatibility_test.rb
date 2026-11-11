# typed: false
# frozen_string_literal: true

require "test_helper"

# These retired mutation endpoints are absent from both owned Auth surfaces.
class AuthSettingsRemovalCompatibilityTest < ActionDispatch::IntegrationTest
  test "retired Auth passkey removal endpoints are unroutable on every surface" do
    {
      app: ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
      org: ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
    }.each_value do |host|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("https://#{host}/settings/passkeys/any/removal", method: :post)
      end
    end
  end
end
