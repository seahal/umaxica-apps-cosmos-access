# typed: false
# frozen_string_literal: true

require "test_helper"

class SignOutOneshotContractTest < ActionDispatch::IntegrationTest
  test "Visa App and Org retain their OIDC logout routes" do
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    cases = [
      [hosts.visa_service.host, "visa/app"],
      [hosts.visa_staff.host, "visa/org"],
    ]

    cases.each do |host, namespace|
      routes = [
        ["/oidc/logout", :get, "#{namespace}/oidc/logouts", "show"],
        ["/oidc/logout", :post, "#{namespace}/oidc/logouts", "create"],
        ["/oidc/logout/confirmation", :post, "#{namespace}/oidc/logouts/confirmations", "create"],
        ["/oidc/logout/completion", :get, "#{namespace}/oidc/logouts/completions", "show"],
      ]

      routes.each do |path, method, expected_controller, expected_action|
        route = Rails.application.routes.recognize_path("https://#{host}#{path}", method: method)

        assert_equal [expected_controller, expected_action], [route.fetch(:controller), route.fetch(:action)], host
      end
    end
  end

  test "Visa OIDC logout does not expose a DELETE route" do
    hosts = Rails.configuration.x.boot_config.fetch(:hosts)
    visa_hosts = [hosts.visa_service.host, hosts.visa_staff.host]

    visa_hosts.each do |host|
      assert_raises(ActionController::RoutingError, host) do
        Rails.application.routes.recognize_path("https://#{host}/oidc/logout", method: :delete)
      end
    end
  end

  test "/sign/out/complete is unroutable and completions controllers are gone" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("/sign/out/complete", method: :get)
    end

    %w(Auth Core Warp).each do |surface|
      %w(App Com Org).each do |face|
        assert_not Object.const_defined?("#{surface}::#{face}::Sign::Outs::CompletionsController")
      end
    end

    assert_equal 5.minutes, Valkey::AuthState::SignOutNoticeStore::TTL
  end
end
