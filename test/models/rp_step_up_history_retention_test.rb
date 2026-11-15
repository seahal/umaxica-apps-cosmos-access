# frozen_string_literal: true

require "test_helper"

class RpStepUpHistoryRetentionTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "step-up state transitions prevent deleting the state in Active Record and PostgreSQL" do
    principal = RpBaseAppPrincipal.create!
    identity_binding = RpBaseAppIdentityBinding.create!(
      principal: principal,
      issuer: "https://visa.umaxica.app",
      realm: RpBaseAppIdentityBinding::REALM,
      client_id: RpBaseAppIdentityBinding::CLIENT_ID,
      subject: SecureRandom.urlsafe_base64(24),
    )
    op_session_binding = RpBaseAppOpSessionBinding.create!(
      identity_binding: identity_binding,
      issuer: identity_binding.issuer,
      realm: RpBaseAppOpSessionBinding::REALM,
      client_id: RpBaseAppOpSessionBinding::CLIENT_ID,
      sid: SecureRandom.urlsafe_base64(24),
    )
    rp_session = RpBaseAppSession.create!(
      op_session_binding: op_session_binding,
      absolute_expires_at: 1.day.from_now,
    )
    now = RpStepUpState.database_now
    state = RpStepUpState.create!(
      public_id: PublicId.generate,
      rp_session: rp_session,
      state_digest: Digest::SHA256.hexdigest("state"),
      browser_binding_digest: Digest::SHA256.hexdigest("browser"),
      nonce_digest: Digest::SHA256.hexdigest("nonce"),
      pkce_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest("verifier"), padding: false),
      pkce_verifier_ciphertext: "test-ciphertext",
      issuer: identity_binding.issuer,
      realm: "APP",
      client_id: "base-app-ww",
      return_target: "/settings",
      initiating_generation: 0,
      state_id: RpStepUpStateStatus::PENDING,
      expires_at: now + 1.minute,
    )
    transition = RpStepUpStateTransition.create!(
      owner: state,
      from_state_id: RpStepUpStateStatus::PENDING,
      to_state_id: RpStepUpStateStatus::DISPATCHING,
      reason_code: "dispatch_started",
      occurred_at: now,
    )

    assert_raises(ActiveRecord::DeleteRestrictionError) { state.destroy! }
    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        RpBaseAppRecord.transaction(requires_new: true) { state.delete }
      end
    assert_instance_of PG::RestrictViolation, error.cause
    assert RpStepUpStateTransition.exists?(transition.id)
  end

  test "step-up audit delivery attempts prevent deleting their outbox in Active Record and PostgreSQL" do
    outbox = RpStepUpAuditOutbox.create!(
      event_uuid: SecureRandom.uuid,
      event_type: "step_up.requested",
      realm: "APP",
      client_id: "base-app-ww",
      subject_ref: "subject-ref",
      context_ref: "a" * 21,
      reason_code: "requested",
      payload: { rp_state_ref: "rp-state", return_target_kind: "relative" },
      occurred_at: Time.current,
      delivery_state: RpStepUpAuditOutboxDeliveryState.find(RpStepUpAuditOutboxDeliveryState::PENDING),
    )
    attempt = RpStepUpAuditOutboxAttempt.create!(
      outbox: outbox,
      attempt_number: 1,
      attempted_at: Time.current,
      outcome: "failed",
      failure_code: "delivery_failed",
    )

    assert_raises(ActiveRecord::DeleteRestrictionError) { outbox.destroy! }
    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        RpBaseAppRecord.transaction(requires_new: true) { outbox.delete }
      end
    assert_instance_of PG::RestrictViolation, error.cause
    assert RpStepUpAuditOutboxAttempt.exists?(attempt.id)
  end
end
