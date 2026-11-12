# frozen_string_literal: true

require "test_helper"

class SignUpGovernanceCleanupBoundaryTest < ActiveSupport::TestCase
  test "termination and cleanup refuse without changing historical flows or audit records" do
    ClientSignUpFlowStatus.ensure_defaults!
    ClientSignUpFlowCleanupStatus.ensure_defaults!
    ClientOidcAuthorizationTransactionStatus.ensure_defaults!
    ClientAuthAdmissionBindingStatus.ensure_defaults!
    now = Time.current
    flows =
      [false, true].map do |terminal|
        transaction_id = SecureRandom.uuid
        transaction = ClientOidcAuthorizationTransaction.insert_all!(
          [{
            transaction_id: transaction_id,
            surface: "app",
            intent: "sign_up",
            client_id: "client",
            redirect_uri: "https://example.test/callback",
            response_type: "code",
            scope: "openid",
            state: "state",
            nonce: "nonce",
            code_challenge: "challenge",
            code_challenge_method: "S256",
            login_challenge: SecureRandom.uuid,
            login_challenge_expires_at: now + 5.minutes,
            expires_at: now + 5.minutes,
            status_id: 10,
          }], returning: %w(id),
        ).rows.first.first
        binding = ClientAuthAdmissionBinding.insert_all!(
          [{
            entry_ref: SecureRandom.uuid,
            purpose: "authentication_handoff",
            entry_intent: "sign_up",
            authorization_transaction_id: transaction,
            base_browser_digest: "a" * 64,
            expires_at: now + 5.minutes,
            curfew_at: now + 5.minutes,
            status_id: 10,
          }], returning: %w(id),
        ).rows.first.first
        id = ClientSignUpFlow.insert_all!(
          [{
            public_id: SecureRandom.alphanumeric(21),
            principal_id: 123,
            state: terminal ? "CANCELLED" : "STARTED",
            step: terminal ? "cancelled" : "start",
            nonce_digest: "b" * 64,
            issued_at: now,
            expires_at: now + 5.minutes,
            entry_method: "email",
            auth_admission_binding_id: binding,
            status_id: terminal ? ClientSignUpFlowStatus::CANCELLED : ClientSignUpFlowStatus::STARTED,
            cleanup_status_id: terminal ? ClientSignUpFlowCleanupStatus::PENDING : ClientSignUpFlowCleanupStatus::IDLE,
            cancelled_at: terminal ? now : nil,
          }], returning: %w(id),
        ).rows.first.first
        ClientSignUpFlow.find(id)
      end
    original = flows.map(&:attributes)
    audit_counts = [Chronicle.count, ClientChronicle.count]

    flows.each do |flow|
      assert_raises(GovernanceLookupUnavailableError) { SignUpTermination.call(cycle: flow, event: :cancel) }
      assert_raises(GovernanceLookupUnavailableError) do
        SignUpTermination.halt_if_phase_violation(cycle: flow) { { halt: true } }
      end
      assert_raises(GovernanceLookupUnavailableError) { SignUpArtifactCleanup.call(cycle: flow) }
    end
    assert_raises(GovernanceLookupUnavailableError) { SignUpArtifactCleanup.cleanup_pending! }
    assert_raises(GovernanceLookupUnavailableError) do
      SignUpArtifactCleanup.cleanup_pending_for(ClientSignUpFlow, now: now, batch_size: 1)
    end
    assert_equal original, flows.map { |flow| flow.reload.attributes }
    assert_equal audit_counts, [Chronicle.count, ClientChronicle.count]
  end
end
