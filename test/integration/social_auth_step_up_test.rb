# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class SocialAuthStepUpTest < ActionDispatch::IntegrationTest
  fixtures :client_statuses

  setup do
    @host = ENV.fetch("PRIVATE_AUTH_SERVICE_URL")
    @user = Client.create!(
      security_mode_id: SecurityModeConfigurable::NORMAL,
      status_id: ClientStatus::ACTIVE,
      public_id: PublicId.generate,
      last_step_up_at: nil,
    )
  end

  test "social auth entry rejects step_up intent" do
    http_headers_0 =
      begin
        rp_headers = as_user_headers(@user, host: @host)
        rp_host = rp_headers["Host"]
        rp_route =
          begin
            Rails.application.routes.recognize_path("https://#{rp_host}/") if rp_host.present?
          rescue ActionController::RoutingError
            nil
          end
        rp_family, rp_surface = rp_route&.fetch(:controller)&.split("/")
        rp_headers
      end
    post auth_app_social_google_session_url(intent: "step_up", ri: "jp"),
         headers: http_headers_0

    assert_response :forbidden
    assert_equal I18n.t("errors.messages.operation_not_permitted"), response.body
    assert_includes response.headers["Cache-Control"].to_s, "no-store"
    assert_not_equal "step_up", session[SocialAuth::SOCIAL_INTENT_SESSION_KEY]
    assert_nil @user.reload.last_step_up_at
  end

  private

  def host_headers(host = nil)
    host_value = host || (respond_to?(:request, true) ? request&.host : nil) || ENV["DEFAULT_URL_HOST"]
    headers = {
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
    }
    headers["Host"] = host_value if host_value.present?
    headers
  end

  def browser_headers
    csrf_token = "test_csrf_token"
    headers = {
      "Client-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 " \
                        "(KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36",
      "X-CSRF-Token" => csrf_token,
    }

    if respond_to?(:cookies, true)
      cookies["csrf_token"] = csrf_token
    else
      headers["Cookie"] = "csrf_token=#{csrf_token}"
    end

    headers
  end

  def bearer_headers(token, host: nil, headers: {})
    host_headers(host).merge(headers).merge("Authorization" => "Bearer #{token}")
  end

  def jwt_issuer_id_for_test_host(host, resource_type)
    normalized = host.to_s
    service = normalized.include?("acme") ? "ACME" : (normalized.include?("core") ? "CORE" : "AUTH")
    surface =
      if service == "AUTH"
        case resource_type
        when "operator" then "ORG"
        else "APP"
        end
      elsif normalized.include?(".org") || normalized.include?("org.")
        "ORG"
      elsif normalized.include?(".com") || normalized.include?("com.")
        "COM"
      else
        "APP"
      end
    "surface:#{service}_#{surface}"
  end
end

# DAMP auth header helpers for this test class.
class SocialAuthStepUpTest
  private
end
