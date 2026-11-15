# typed: false
# frozen_string_literal: true

require "test_helper"

# The unavailable registration handler must still reject an unsafe request without
# a valid Rails authenticity token.
class Auth::App::SignUpCsrfFailureTest < ActionDispatch::IntegrationTest
  setup do
    @host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
    host! @host
  end

  test "a telephone sign-up submission without a token is refused before the unavailable response" do
    controller = Auth::App::UnavailableCeremoniesController
    original_protection = controller.allow_forgery_protection
    controller.allow_forgery_protection = true

    begin
      post(
        auth_app_sign_up_telephone_url(ri: "jp", format: :json),
        params: { user_telephone: { raw_number: "+1234567890" } },
        headers: { "Host" => @host, "Origin" => "null" },
      )

      assert_response :unprocessable_content
      assert_not_equal "Service unavailable", response.body
    ensure
      controller.allow_forgery_protection = original_protection
    end
  end
end
