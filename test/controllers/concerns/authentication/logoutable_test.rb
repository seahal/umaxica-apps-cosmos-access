# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Authentication
  class LogoutableTest < ActiveSupport::TestCase
    self.fixture_table_names = []
    # ------------------------------------------------------------------
    # Regression coverage for "ordinary logout must not revoke other
    # sessions" (S-0). If it regresses, this test fails loudly.
    # ------------------------------------------------------------------
    test "Oidc::SingleLogoutService is intentionally absent" do
      # The misleadingly-named Oidc::SingleLogoutService used to live at
      # `app/services/oidc/single_logout_service.rb` and revoked every
      # active token for the actor. It was deleted because (a) its name
      # promised OIDC SLO-protocol semantics while doing something else,
      # and (b) principal-wide identity decisions now belong to Governance.
      # If this guard fails, keep the deletion: current-device logout must
      # not acquire authority to stop another device.
      assert_not defined?(Oidc::SingleLogoutService),
                 "Oidc::SingleLogoutService must remain deleted. See " \
                 "adr/logout-primitive-and-composition.md."
    end
  end
end
