# frozen_string_literal: true

require "test_helper"

class OpBrowserRefreshCookieSizeTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = %w(client_tokens operator_tokens client_device_sessions operator_device_sessions)

  test "APP browser refresh keeps the PS256 access cookie within the browser cookie limit" do
    root = ClientToken.includes(:device_session).find(ActiveRecord::FixtureSet.identify(:one))
    refresh_token = root.rotate_refresh_token!
    cookie_name = AuthenticationCookieName.access
    production_cookie_name = AuthenticationCookieName.access(production: true)
    host!("visa.umaxica.app")
    https!
    cookies[AuthenticationCookieName.refresh] = refresh_token

    post "/edge/v0/token/refresh", headers: { "Accept" => "application/json" }

    assert_response :ok
    access_cookie_value = response.cookies.fetch(cookie_name)

    assert_operator "#{production_cookie_name}=#{access_cookie_value}".bytesize, :<=, 4096
  end

  test "ORG browser refresh keeps the PS256 access cookie within the browser cookie limit" do
    root = OperatorToken.includes(:device_session).find(ActiveRecord::FixtureSet.identify(:one))
    root.update!(authentication_context: "normal")
    refresh_token = root.rotate_refresh_token!
    cookie_name = AuthenticationCookieName.access
    production_cookie_name = AuthenticationCookieName.access(production: true)
    host!("visa.umaxica.org")
    https!
    cookies[AuthenticationCookieName.refresh] = refresh_token

    post "/edge/v0/token/refresh", headers: { "Accept" => "application/json" }

    assert_response :ok
    access_cookie_value = response.cookies.fetch(cookie_name)

    assert_operator "#{production_cookie_name}=#{access_cookie_value}".bytesize, :<=, 4096
  end
end
