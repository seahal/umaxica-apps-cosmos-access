# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::IdentityAuthoritySlice1ATest < ActionDispatch::IntegrationTest
  test "auth does not expose authorization-server authority routes" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("PRIVATE_AUTH_SERVICE_URL")}/oauth/token",
        method: :post,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("PRIVATE_AUTH_SERVICE_URL")}/oauth/userinfo",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("PRIVATE_AUTH_SERVICE_URL")}/oidc/jwks",
        method: :get,
      )
    end
  end

  test "auth settings sessions route is retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("PRIVATE_AUTH_SERVICE_URL")}/settings/sessions",
        method: :get,
      )
    end
  end

  test "auth withdrawal route is retired" do
    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("PRIVATE_AUTH_SERVICE_URL")}/settings/withdrawal/new",
        method: :get,
      )
    end
  end

  test "auth sign in and sign up entry routes still resolve on auth" do
    sign_in = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("PRIVATE_AUTH_SERVICE_URL")}/sign/in",
      method: :get,
    )
    sign_up = Rails.application.routes.recognize_path(
      "https://#{ENV.fetch("PRIVATE_AUTH_SERVICE_URL")}/sign/up",
      method: :get,
    )

    assert_equal "auth/app/sign/ins", sign_in.fetch(:controller)
    assert_equal "show", sign_in.fetch(:action)
    assert_equal "auth/app/sign/ups", sign_up.fetch(:controller)
    assert_equal "show", sign_up.fetch(:action)
  end

  test "Auth sign-out relay routes are absent" do
    %i(get post patch put delete).each do |method|
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path(
          "https://#{ENV.fetch("PRIVATE_AUTH_SERVICE_URL")}/sign/out",
          method: method,
        )
      end
    end
  end

  test "Visa owns OIDC logout while Auth has no sign-out route" do
    oidc_logout = Rails.application.routes.recognize_path(
      "https://#{Rails.configuration.x.boot_config.fetch(:hosts).visa_service.host}/oidc/logout",
      method: :get,
    )

    assert_equal "visa/app/oidc/logouts", oidc_logout.fetch(:controller)
    assert_equal "show", oidc_logout.fetch(:action)

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("PRIVATE_AUTH_SERVICE_URL")}/oidc/logout",
        method: :get,
      )
    end

    assert_raises(ActionController::RoutingError) do
      Rails.application.routes.recognize_path(
        "https://#{ENV.fetch("PRIVATE_AUTH_SERVICE_URL", "auth.app.localhost")}/oauth/token",
        method: :post,
      )
    end
  end
end
