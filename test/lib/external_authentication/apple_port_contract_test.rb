# frozen_string_literal: true

require "test_helper"

class ExternalAuthentication::ApplePortContractTest < ActiveSupport::TestCase
  test "Apple credential revocation requires a concrete adapter" do
    port = Object.new.extend(ExternalAuthentication::AppleCredentialRevocationPort)

    assert_raises(NotImplementedError) { port.call(refresh_token: "opaque-refresh-token") }
  end

  test "Apple notification verification requires a concrete adapter" do
    port = Object.new.extend(ExternalAuthentication::AppleNotificationVerifierPort)

    assert_raises(NotImplementedError) { port.call }
  end
end
