# frozen_string_literal: true

require "test_helper"

class SocialCeremonyStartGateTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  { "google" => :social_ceremony_app_google, "apple" => :social_ceremony_app_apple }.each do |provider, feature|
    [true, false].each do |enabled|
      test "#{provider} refuses sign-in and signup when provider flag is #{enabled ? "enabled" : "disabled"}" do
        flag = FeatureFlags::REGISTRY.fetch(feature).name
        previous = Flipper.enabled?(flag)
        enabled ? Flipper.enable(flag) : Flipper.disable(flag)
        host!(ENV.fetch("PUBLIC_AUTH_SERVICE_URL"))
        https!
        before = [ClientSignUpFlow.count, ClientSignInFlow.count, ClientAuthCeremonySession.count]
        ["/social/#{provider}/session", "/social/#{provider}/registration"].each do |path|
          post(path)

          assert_response :service_unavailable
          assert_nil response.location
          assert_equal before, [ClientSignUpFlow.count, ClientSignInFlow.count, ClientAuthCeremonySession.count]
          assert_nil session[:social_ceremony_grant]
          assert_nil session[:social_auth_intent]
        end
      ensure
        previous ? Flipper.enable(flag) : Flipper.disable(flag)
      end
    end
  end
end
