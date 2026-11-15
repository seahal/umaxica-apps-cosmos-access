# frozen_string_literal: true

require "test_helper"

# Preference cookie and theme APIs were removed with their Governance-owned data.
class PreferenceApiRouteContractTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  AUTH_HOSTS = {
    "app" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
    "org" => ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
  }.freeze
  RESOURCES = { "theme" => "themes", "cookie" => "cookies" }.freeze

  test "Visa hosts do not expose Auth preference APIs" do
    [Rails.configuration.x.boot_config.fetch(:hosts).visa_service.host,
     Rails.configuration.x.boot_config.fetch(:hosts).visa_staff.host,].each do |host|
      RESOURCES.each_key do |resource|
        %i(get patch put).each do |method|
          assert_raises(ActionController::RoutingError, "#{method} #{host}/api/v0/preferences/#{resource}") do
            Rails.application.routes.recognize_path("http://#{host}/api/v0/preferences/#{resource}", method: method)
          end
        end
      end
    end
  end

  test "auth email OTP entry stays routed to the unavailable ceremony boundary" do
    recognized = Rails.application.routes.recognize_path(
      "http://#{AUTH_HOSTS.fetch("app")}/web/v0/in/email/otp",
      method: :post,
    )

    assert_equal "auth/app/unavailable_ceremonies", recognized[:controller]
  end
end
