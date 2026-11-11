# frozen_string_literal: true

require "test_helper"
require_relative "../support/openapi_contract"

# Validates the retained Auth App and Org read-only preference API contracts.
class OpenapiPreferencesContractTest < ActionDispatch::IntegrationTest
  include OpenapiContract

  SURFACE_HOST_KEYS = { "app" => "SERVICE", "org" => "STAFF" }.freeze
  JSON_HEADERS = { "Accept" => "application/json", "Content-Type" => "application/json" }.freeze

  %w(app org).each do |surface|
    test "Auth #{surface} preference endpoints conform to the #{surface} description" do
      self.openapi_surface = surface
      host! ENV.fetch("PUBLIC_AUTH_#{SURFACE_HOST_KEYS.fetch(surface)}_URL")

      get "/api/v0/preferences/theme", headers: { "Accept" => "application/json" }

      assert_response :ok
      assert_openapi_conform 200

      get "/api/v0/preferences/cookie", headers: { "Accept" => "application/json" }

      assert_response :ok
      assert_openapi_conform 200

      patch "/api/v0/preferences/theme", params: { theme: "dark" }.to_json, headers: JSON_HEADERS

      assert_response :forbidden
      assert_openapi_response_conform 403

      patch "/api/v0/preferences/cookie", params: { cookie: { consented: true, functional: false } }.to_json,
                                          headers: JSON_HEADERS

      assert_response :forbidden
      assert_openapi_response_conform 403
    end
  end
end
