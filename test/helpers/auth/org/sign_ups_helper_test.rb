# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class AuthOrgSignUpsHelperTest < ActionView::TestCase
  setup do
    extend Auth::Org::SignUpsHelper
  end

  test "auth_org_recruit_contact_url returns the configured safe direct message URL" do
    with_env("ORG_SIGN_UP_DIRECT_MESSAGE_URL" => "https://contact.example.test/recruit?team=org") do
      assert_equal "https://contact.example.test/recruit?team=org", auth_org_recruit_contact_url
    end
  end

  test "auth_org_recruit_contact_url omits an unsafe direct message URL" do
    with_env("ORG_SIGN_UP_DIRECT_MESSAGE_URL" => "javascript:alert(1)") do
      assert_nil auth_org_recruit_contact_url
    end
  end

  test "auth_org_recruit_contact_url does not guess a root URL when unset" do
    with_env("ORG_SIGN_UP_DIRECT_MESSAGE_URL" => nil) do
      assert_nil auth_org_recruit_contact_url
    end
  end

  private

  def with_env(values)
    previous = {}
    values.each do |key, value|
      previous[key] = ENV[key]
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
    yield
  ensure
    previous.each do |key, value|
      value.nil? ? ENV.delete(key) : ENV[key] = value
    end
  end
end
