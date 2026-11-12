# frozen_string_literal: true

require "test_helper"

class SocialCeremonyEntryContractTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  %w(google apple).each do |provider|
    test "#{provider} session and registration entry fail closed without redirect or state" do
      host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      https!
      before = [ClientSignUpFlow.count, ClientSignInFlow.count, ClientToken.count, ClientAuthCeremonySession.count]
      ["/social/#{provider}/session", "/social/#{provider}/registration", "/social/#{provider}"].each do |path|
        post path

        assert_response :service_unavailable
        assert_equal "Service unavailable", response.body
        assert_nil response.location
        assert_equal before, [ClientSignUpFlow.count, ClientSignInFlow.count, ClientToken.count,
                              ClientAuthCeremonySession.count,]
      end
    end

    test "#{provider} cross-site submission remains blocked by CSRF protection" do
      original = Auth::App::UnavailableCeremoniesController.allow_forgery_protection
      Auth::App::UnavailableCeremoniesController.allow_forgery_protection = true
      host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
      https!
      post(
        "/social/#{provider}", params: { authenticity_token: "not-a-real-token" }, headers: {
          "Origin" => "https://attacker.example.test", "Sec-Fetch-Site" => "cross-site",
        },
      )

      assert_response :unprocessable_content
      assert_not_equal "Service unavailable", response.body
      assert_nil response.location
    ensure
      Auth::App::UnavailableCeremoniesController.allow_forgery_protection = original
    end

    test "#{provider} cannot start a ceremony through a GET" do
      host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
      https!
      ["/social/#{provider}/session", "/social/#{provider}/session/new",
       "/social/#{provider}/registration", "/social/#{provider}/registration/new",].each do |path|
        get path

        assert_response :not_found
        assert_nil response.location
      end
    end
  end
end
