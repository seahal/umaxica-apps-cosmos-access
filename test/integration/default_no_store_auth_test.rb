# typed: false
# frozen_string_literal: true

require "test_helper"

# Auth-owned responses start from `Cache-Control: no-store` (adr/global-and-publishing-default-no-store-policy.md).
class DefaultNoStoreAuthTest < ActionDispatch::IntegrationTest
  test "Auth app root is an unowned 404 without a redirect" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")

    get("/", params: { ri: "jp" })

    assert_response :not_found
    assert_equal({ "error" => "unknown_host" }, response.parsed_body)
    assert_nil response.headers["Location"]
  end

  test "Auth app ApplicationController region redirect issued by a callback is no-store" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")

    get("/sign/in")

    assert_response :found
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Auth app ApplicationController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:auth_service))
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")

    get("/sign/in", params: { ri: "jp" })

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Auth org root is an unowned 404 without a redirect" do
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL")

    get("/", params: { ri: "jp" })

    assert_response :not_found
    assert_equal({ "error" => "unknown_host" }, response.parsed_body)
    assert_nil response.headers["Location"]
  end

  test "Auth org ApplicationController region redirect issued by a callback is no-store" do
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL")

    get("/sign/in")

    assert_response :found
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Auth org ApplicationController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:auth_staff))
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL")

    get("/sign/in", params: { ri: "jp" })

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Auth app BareController robots.txt is no-store" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")

    get("/robots.txt")

    assert_response :success
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Auth app BareController sitemap keeps its explicit public cache opt-in" do
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")

    get("/sitemap.xml")

    assert_response :success
    cache_control = response.headers.fetch("Cache-Control").split(", ")

    assert_includes cache_control, "public"
    assert_includes cache_control, "max-age=300"
    assert_includes cache_control, "s-maxage=600"
    assert_not_includes cache_control, "no-store"
  end

  test "Auth app BareController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:auth_service))
    host! ENV.fetch("PUBLIC_AUTH_SERVICE_URL")

    get("/robots.txt")

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Auth org BareController robots.txt is no-store" do
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL")

    get("/robots.txt")

    assert_response :success
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end

  test "Auth org BareController sitemap keeps its explicit public cache opt-in" do
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL")

    get("/sitemap.xml")

    assert_response :success
    cache_control = response.headers.fetch("Cache-Control").split(", ")

    assert_includes cache_control, "public"
    assert_includes cache_control, "max-age=300"
    assert_includes cache_control, "s-maxage=600"
    assert_not_includes cache_control, "no-store"
  end

  test "Auth org BareController response halted by the availability gate is no-store" do
    Flipper.disable(FqdnAvailabilityRegistry.flag_name_for(:auth_staff))
    host! ENV.fetch("PUBLIC_AUTH_STAFF_URL")

    get("/robots.txt")

    assert_response :service_unavailable
    assert_equal "no-store", response.headers.fetch("Cache-Control")
  end
end
