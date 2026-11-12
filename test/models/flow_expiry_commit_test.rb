# frozen_string_literal: true

require "test_helper"

class FlowExpiryCommitTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  test "unavailable sign-in transitions fail closed without mutating expired flows" do
    [ClientSignInFlow, OperatorSignInFlow].each do |model|
      flow = nil
      begin
        now = model.database_now
        flow = model.create!(
          nonce_digest: model.digest_nonce(SecureRandom.hex(16)),
          issued_at: now - 2.minutes, expires_at: now - 1.minute,
        )

        original = flow.attributes

        assert_not model.lease_connection.transaction_open?
        assert_raises(GovernanceLookupUnavailableError) { flow.complete_sign_in! }
        assert_equal original, model.find(flow.id).attributes
        assert_predicate model.find(flow.id), :sign_in_expired?
      ensure
        flow&.destroy!
      end
    end
  end
  test "unavailable sign-in transition remains fail closed under reading role and caller transaction" do
    [ClientSignInFlow, OperatorSignInFlow].each do |model|
      flow = nil
      begin
        now = model.database_now
        flow = model.create!(
          nonce_digest: model.digest_nonce(SecureRandom.hex(16)),
          issued_at: now - 2.minutes, expires_at: now - 1.minute,
        )
        original = flow.attributes
        assert_raises(GovernanceLookupUnavailableError) do
          model.transaction do
            model.connection_class_for_self.connected_to(role: :reading) { flow.advance_sign_in_to_mfa! }
          end
          end

        assert_equal original, model.find(flow.id).attributes
        assert_predicate model.find(flow.id), :sign_in_expired?
      ensure
        flow&.destroy!
      end
    end
  end
end
