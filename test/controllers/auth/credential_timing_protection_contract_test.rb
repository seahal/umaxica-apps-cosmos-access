# typed: false
# frozen_string_literal: true

require "test_helper"
require Rails.root.join("lib/omniauth/strategies/umaxica_entra")

class AuthCredentialTimingProtectionContractTest < ActiveSupport::TestCase
  # The Entra strategy's request phase used to pad its response time so a valid
  # and an invalid connection_public_id could not be told apart by timing. The
  # org surface now federates a single tenant read from configuration, so the
  # request phase performs no per-request record lookup and there is no pair of
  # inputs whose timing could differ. The protection was removed with the lookup
  # rather than left as a pad over nothing; this asserts the lookup really is
  # gone, which is what made it unnecessary.
  test "Entra OmniAuth strategy's request phase performs no timing-sensitive record lookup" do
    strategy_class = OmniAuth::Strategies::UmaxicaEntra
    body = File.read(strategy_class.instance_method(:request_phase).source_location.first)

    assert_not_includes strategy_class.private_instance_methods, :active_connection
    assert_no_match(/OrganizationEntraConnection/, body)
  end
end
