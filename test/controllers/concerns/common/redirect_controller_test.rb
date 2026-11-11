# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class CommonRedirectControllerTest < ActionDispatch::IntegrationTest
  test "normalize_host strips scheme from URL" do
    result = CommonRedirect.normalize_host("http://example.com/path")

    assert_includes result, "example.com"
    result = CommonRedirect.normalize_host("https://example.com")

    assert_includes result, "example.com"
  end

  test "normalize_host handles localhost" do
    result = CommonRedirect.normalize_host("localhost:3000")

    assert_includes result, "localhost"
    result = CommonRedirect.normalize_host("http://localhost")

    assert_includes result, "localhost"
  end

  test "normalize_host handles subdomains" do
    assert_equal "sub.example.com", CommonRedirect.normalize_host("https://sub.example.com/path")
  end

  test "normalize_host returns nil for invalid input" do
    assert_nil CommonRedirect.normalize_host(nil)
    assert_nil CommonRedirect.normalize_host("")
  end
end
