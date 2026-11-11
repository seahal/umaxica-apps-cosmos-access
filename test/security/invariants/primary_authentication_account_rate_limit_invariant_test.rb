# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    class PrimaryAuthenticationAccountRateLimitInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      test "app publishes its admitted secret credential ceremony" do
        host = ENV.fetch("PUBLIC_AUTH_SERVICE_URL")
        { get: ["/sign/in/secret/new", "new"], post: ["/sign/in/secret", "create"] }.each do |method, (path, action)|
          route = Rails.application.routes.recognize_path("https://#{host}#{path}", method: method)

          assert_equal "auth/app/sign/in/secrets", route.fetch(:controller)
          assert_equal action, route.fetch(:action)
        end
      end

      test "Auth org does not expose the app secret sign-in path" do
        host = Rails.configuration.x.boot_config.fetch(:hosts).auth_staff.host

        %i(get post).each do |method|
          assert_raises(ActionController::RoutingError) do
            Rails.application.routes.recognize_path("http://#{host}/sign/in/secret", method: method)
          end
        end
      end
    end
  end
end
