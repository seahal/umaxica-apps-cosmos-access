# typed: false
# frozen_string_literal: true

require "test_helper"

class VisaSignInRestartGuidanceTest < ActionDispatch::IntegrationTest
  test "APP invalid resolution is refused without changing session state" do
    visa_host = ENV.fetch("PUBLIC_VISA_SERVICE_URL")
    host! visa_host
    https!
    cookies_before = cookies.to_hash.deep_dup
    resolutions_before = ClientSessionLimitResolutionTransaction.order(:id).map(&:attributes)
    get visa_app_sign_in_limitation_path(ri: "jp", return_to: "https://attacker.invalid"),
        headers: { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }

    assert_response :gone
    assert_not_includes response.body, "attacker.invalid"
    assert_equal cookies_before, cookies.to_hash
    assert_equal resolutions_before, ClientSessionLimitResolutionTransaction.order(:id).map(&:attributes)
  end

  test "ORG invalid resolution is refused without changing session state" do
    visa_host = ENV.fetch("PUBLIC_VISA_STAFF_URL")
    host! visa_host
    https!
    cookies_before = cookies.to_hash.deep_dup
    resolutions_before = OperatorSessionLimitResolutionTransaction.order(:id).map(&:attributes)
    get visa_org_sign_in_limitation_path(ri: "jp", return_to: "https://attacker.invalid"),
        headers: { "Sec-Fetch-Mode" => "navigate", "Sec-Fetch-Dest" => "document" }

    assert_response :gone
    assert_not_includes response.body, "attacker.invalid"
    assert_equal cookies_before, cookies.to_hash
    assert_equal resolutions_before, OperatorSessionLimitResolutionTransaction.order(:id).map(&:attributes)
  end
end
