# frozen_string_literal: true

require "test_helper"

# Preference cookie and theme APIs belong to the retained Auth credential surfaces.
class PreferenceApiRouteContractTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  AUTH_HOSTS = {
    "app" => ENV.fetch("PUBLIC_AUTH_SERVICE_URL"),
    "org" => ENV.fetch("PUBLIC_AUTH_STAFF_URL"),
  }.freeze
  RESOURCES = { "theme" => "themes", "cookie" => "cookies" }.freeze

  test "Auth app and org expose only GET and PATCH preference APIs" do
    AUTH_HOSTS.each do |surface, host|
      RESOURCES.each do |resource, controller|
        url = "http://#{host}/api/v0/preferences/#{resource}"

        %i(get patch).each do |method|
          recognized = Rails.application.routes.recognize_path(url, method: method)

          assert_equal "auth/#{surface}/api/v0/preferences/#{controller}", recognized.fetch(:controller)
        end
        assert_raises(ActionController::RoutingError, "PUT #{url}") do
          Rails.application.routes.recognize_path(url, method: :put)
        end
      end
    end
  end

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

  test "auth keeps the email OTP ceremony under the web namespace" do
    recognized = Rails.application.routes.recognize_path(
      "http://#{AUTH_HOSTS.fetch("app")}/web/v0/in/email/otp",
      method: :post,
    )

    assert_equal "auth/app/web/v0/in/email/otps", recognized[:controller]
  end
end
