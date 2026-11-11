# frozen_string_literal: true

require "test_helper"

class GlobalRegionCanonicalizationTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  CEREMONY_HOSTS = %w(
    PUBLIC_AUTH_SERVICE_URL PUBLIC_AUTH_STAFF_URL
    PUBLIC_VISA_SERVICE_URL PUBLIC_VISA_STAFF_URL
  ).freeze

  test "Auth and Visa have no root home for missing, invalid, or valid regions" do
    CEREMONY_HOSTS.each do |environment_key|
      host! ENV.fetch(environment_key)

      [{}, { ri: "xx" }, { ri: "jp" }, { ri: "us" }].each do |params|
        get "/", params: params

        assert_response :not_found
        assert_nil response.location
        assert_equal "unknown_host", response.parsed_body.fetch("error")
      end
    end
  end

  test "Visa protocol metadata does not canonicalize missing region" do
    %w(PUBLIC_VISA_SERVICE_URL PUBLIC_VISA_STAFF_URL).each do |environment_key|
      host! ENV.fetch(environment_key)
      get "/.well-known/openid-configuration"

      assert_response :ok
      assert_nil response.location
      assert_equal "application/json", response.media_type
    end
  end
end
