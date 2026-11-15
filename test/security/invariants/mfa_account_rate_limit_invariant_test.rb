# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    # Second-factor verification must be bounded per account, not only per source IP.
    # An IP-keyed limit alone leaves a distributed attacker unbounded guesses against
    # one account's 6-digit TOTP once the primary factor is established. The email
    # and SMS OTP channels already have a per-account lock
    # (app/models/concerns/otp_lockable.rb); these rules are its equivalent for the
    # factors that are verified in-process.
    #
    # A session-scoped counter is deliberately not used: an attacker discards the
    # session and starts a fresh one, so the counter bounds nothing.
    class MfaAccountRateLimitInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      # Auth ceremonies are unavailable until Governance lookup is connected.
      test "no Auth sign-in challenge controller remains mounted" do
        controllers = Rails.root.glob("app/controllers/auth/*/sign/in/challenge/*_controller.rb")
          .map { |path| path.basename.to_s }.uniq

        assert_empty controllers
      end
    end
  end
end
