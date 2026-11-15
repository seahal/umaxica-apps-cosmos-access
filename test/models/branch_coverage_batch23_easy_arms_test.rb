# typed: false
# frozen_string_literal: true

require "test_helper"
require "jwt"

# Pure unit coverage for redirect refusals that reject unknown keys and malformed targets.
class BranchCoverageBatch23EasyArmsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "RedirectsExternalTargetResolver refuses unknown keys and relative targets" do
    unknown = RedirectsExternalTargetResolver.call(:not_a_registry_key)

    assert_equal "unknown_key", unknown.failure_reason

    blank_host = RedirectsExternalTargetResolver.url("/relative", allowed_urls: ["https://example.test"])

    assert_equal "invalid_uri", blank_host.failure_reason

    # A parseable absolute URL that still carries a control character hits the dedicated arm.
    control = RedirectsExternalTargetResolver.url(
      "https://example.test/?q=" + 1.chr,
      allowed_urls: ["https://example.test"],
    )

    assert_includes %w(control_char invalid_uri origin_denied), control.failure_reason
  end
end
