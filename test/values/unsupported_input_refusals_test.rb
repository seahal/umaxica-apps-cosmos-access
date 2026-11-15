# typed: false
# frozen_string_literal: true

require "test_helper"

# A sweep over the places that refuse an input they were never taught. Each is a
# single line, and each is the difference between a value being rejected at the
# boundary and being carried further as though it meant something. They are
# gathered here because the failure mode is identical everywhere: a new surface,
# provider or state added without teaching the mapping must fail loudly.
class UnsupportedInputRefusalsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "a provider whose adapter key has no adapter is refused" do
    entry = Struct.new(:adapter_key).new(:martian_oidc)

    ExternalAuthentication::ProviderRegistry.stub(:fetch, entry) do
      error = assert_raises(ArgumentError) { ExternalAuthentication::ProviderAdapterFactory.build(provider: "martian") }

      assert_match(/adapter is unsupported/, error.message)
    end
  end

  # The challenge verifier is injected through configuration so no production
  # class carries a test-only branch. An unset one has to fail loudly rather than
  # leave every challenge unverified.
  test "an unconfigured challenge verifier is refused rather than skipped" do
    configured = Rails.application.config.x.turnstile.verifier
    Rails.application.config.x.turnstile.verifier = nil

    error = assert_raises(RuntimeError) { Turnstile::VerifierFactory.current }

    assert_match(/turnstile\.verifier is not configured/, error.message)
  ensure
    Rails.application.config.x.turnstile.verifier = configured
  end

  # A decision has to carry when it was observed, because staleness is what
  # decides whether it may still be trusted.
  test "an availability decision without an observation time is refused" do
    error =
      assert_raises(ArgumentError) do
        ExternalAuthentication::AvailabilityDecision.new(
          state: :enabled, source: "flipper", configuration_version: nil,
          reason_code: nil, incident_id: nil, observed_at: "just now",
        )
      end

    assert_match(/observed_at must be a time/, error.message)
  end

  test "a signup-required login result cannot also carry an account" do
    error =
      assert_raises(ArgumentError) do
        ExternalAuthentication::LoginResult.new(
          status: :signup_required, user: Object.new, identity: nil, existing_account: false,
        )
      end

    assert_match(/signup required result cannot contain an account/, error.message)
  end
end
