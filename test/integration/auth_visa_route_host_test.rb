# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthVisaRouteHostTest < ActionDispatch::IntegrationTest
  test "Auth and Visa app and org hosts own their health and OIDC routes" do
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)

    {
      hosts.auth_service.host => ["/health", "auth/app/healths"],
      hosts.auth_staff.host => ["/health", "auth/org/healths"],
      hosts.visa_service.host => ["/.well-known/openid-configuration", "visa/app/well_known/discoveries"],
      hosts.visa_staff.host => ["/.well-known/openid-configuration", "visa/org/well_known/discoveries"],
    }.each do |host, (path, controller)|
      route = Rails.application.routes.recognize_path("https://#{host}#{path}", method: :get)

      assert_equal controller, route[:controller]
      assert_equal "show", route[:action]
    end
  end

  test "retired hosts receive only the shared unknown-host root" do
    root_route = Rails.application.routes.recognize_path("https://retired.example.test/", method: :get)

    assert_equal "unknown_hosts", root_route[:controller]
    assert_equal "show", root_route[:action]
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("https://retired.example.test/health", method: :get)
    end
  end
end
