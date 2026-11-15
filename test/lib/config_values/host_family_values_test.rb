# frozen_string_literal: true

require "test_helper"

class ConfigValuesHostFamilyValuesTest < ActiveSupport::TestCase
  test "host families expose their own auth and visa origins" do
    values = ConfigValues::HostFamilyValues.new(
      auth_service: "https://auth.example.test",
      auth_staff: "https://staff-auth.example.test",
      visa_service: "https://visa.example.test",
      visa_staff: "https://staff-visa.example.test",
    )

    assert_equal %w(https://auth.example.test https://staff-auth.example.test), values.auth_origins
    assert_equal %w(https://visa.example.test https://staff-visa.example.test), values.visa_origins
  end

  test "build requires each configured public host and normalizes an origin" do
    env = {
      "PUBLIC_AUTH_SERVICE_URL" => "auth.example.test",
      "PUBLIC_AUTH_STAFF_URL" => "https://staff-auth.example.test",
      "PUBLIC_VISA_SERVICE_URL" => "visa.example.test",
      "PUBLIC_VISA_STAFF_URL" => "staff-visa.example.test",
    }

    values = ConfigValues::HostFamilyValues.build(env:, production: true)

    assert_equal "https://auth.example.test", values.auth_service.to_s
    assert_equal "https://staff-auth.example.test", values.auth_staff.to_s
    assert_equal "https://visa.example.test", values.visa_service.to_s
    assert_equal "https://staff-visa.example.test", values.visa_staff.to_s
    assert_raises(KeyError) do
      ConfigValues::HostFamilyValues.build(
        env: env.except("PUBLIC_AUTH_SERVICE_URL"), production: true,
      )
    end
  end
end
