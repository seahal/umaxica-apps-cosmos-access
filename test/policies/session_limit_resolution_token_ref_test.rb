# typed: false
# frozen_string_literal: true

require "test_helper"

class SessionLimitResolutionTokenRefTest < ActiveSupport::TestCase

  test "a session-limit token reference that was not signed here resolves to no token" do
    assert_nil SessionLimitResolutionTokenRef.find_client_token("not-a-signed-ref")
    assert_nil SessionLimitResolutionTokenRef.find_client_token(nil)
  end
end
