# typed: false
# frozen_string_literal: true

require "test_helper"

class RpSessionPublicContractTest < ActiveSupport::TestCase
  test "retirement remains pending through the access-token verifier's exact leeway boundary" do
    revoked_at = Time.zone.parse("2026-11-01 12:00:00")
    leeway = SecurityTokenLifetimes::OIDC_ACCESS_JWT_CLOCK_LEEWAY_SECONDS
    session = OpAppGrant.new(
      revoked_at: revoked_at,
      oidc_access_token_max_expires_at: revoked_at + 10.minutes,
    )

    assert session.retirement_pending?(revoked_at + 10.minutes + leeway - 1.second)
    assert_not session.retirement_pending?(revoked_at + 10.minutes + leeway)
    assert_not session.retirement_pending?(revoked_at + 10.minutes + leeway + 1.second)
  end

  test "unknown retirement timing stays pending and inactive grants reject refresh verifiers" do
    unknown_timing = OpOrgGrant.new(revoked_at: Time.zone.parse("2026-11-01 12:00:00"))
    active_without_parent = OpAppGrant.new(
      revoked_at: nil,
      refresh_token_digest: "a" * 64,
      refresh_token_expires_at: 10.minutes.from_now,
    )

    assert unknown_timing.retirement_pending?(Time.zone.parse("2026-12-01 12:00:00"))
    assert_not active_without_parent.authenticate_refresh_token("candidate-verifier")
  end
end
