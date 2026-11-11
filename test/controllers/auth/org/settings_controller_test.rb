# typed: false
# frozen_string_literal: true

require "test_helper"

class Auth::Org::SettingsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @auth_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
    @base_host = ENV.fetch("PUBLIC_AUTH_STAFF_URL")
  end

  test "Auth ORG settings and retired Base identity routes are absent" do
    %w(/settings /settings/entra /settings/entra/edit).each do |path|
      %i(get post put patch delete).each do |method|
        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path("https://#{@auth_host}#{path}", method: method)
        end
      end
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path("https://#{@base_host}/identity/social_identities", method: :get)
    end
  end
end
