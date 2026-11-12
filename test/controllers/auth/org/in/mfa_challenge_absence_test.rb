# typed: false
# frozen_string_literal: true

require "test_helper"

# Retired second-factor paths stay absent while emergency entry explicitly refuses new ceremonies.
class AuthOrgMfaChallengeAbsenceTest < ActionDispatch::IntegrationTest
  ORG_HOST = ENV.fetch("PUBLIC_AUTH_STAFF_URL")

  [
    ["/sign/in/challenge", :get],
    ["/sign/in/challenge", :delete],
    ["/sign/in/challenge/passkey/new", :get],
    ["/sign/in/challenge/passkey", :post],
  ].each do |path, verb|
    test "org host does not route #{verb.upcase} #{path}" do
      assert_raises(ActionController::RoutingError) do
        Rails.application.routes.recognize_path("http://#{ORG_HOST}#{path}", method: verb)
      end
    end
  end

  test "org emergency passkey sign-in stays routed" do
    route = Rails.application.routes.recognize_path("http://#{ORG_HOST}/sign/in/emergency/passkey/new", method: :get)

    assert_equal "auth/org/unavailable_ceremonies", route[:controller]
  end
end
