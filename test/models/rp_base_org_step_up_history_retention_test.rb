# frozen_string_literal: true

require "test_helper"

class RpBaseOrgStepUpHistoryRetentionTest < ActiveSupport::TestCase
  test "step-up state transitions prevent deleting the state in Active Record and PostgreSQL" do
    principal = RpBaseOrgPrincipal.create!
    identity_binding = RpBaseOrgIdentityBinding.create!(
      principal: principal,
      issuer: "https://visa.umaxica.org",
      realm: RpBaseOrgIdentityBinding::REALM,
      client_id: RpBaseOrgIdentityBinding::CLIENT_ID,
      subject: SecureRandom.urlsafe_base64(24),
    )
    op_session_binding = RpBaseOrgOpSessionBinding.create!(
      identity_binding: identity_binding,
      issuer: identity_binding.issuer,
      realm: RpBaseOrgOpSessionBinding::REALM,
      client_id: RpBaseOrgOpSessionBinding::CLIENT_ID,
      sid: SecureRandom.urlsafe_base64(24),
    )
    rp_session = RpBaseOrgSession.create!(
      op_session_binding: op_session_binding,
      absolute_expires_at: 1.day.from_now,
    )
    now = RpBaseOrgStepUpState.database_now
    state = RpBaseOrgStepUpState.create!(
      public_id: PublicId.generate,
      rp_session: rp_session,
      state_digest: Digest::SHA256.hexdigest("state"),
      browser_binding_digest: Digest::SHA256.hexdigest("browser"),
      nonce_digest: Digest::SHA256.hexdigest("nonce"),
      pkce_challenge: Base64.urlsafe_encode64(Digest::SHA256.digest("verifier"), padding: false),
      pkce_verifier_ciphertext: "test-ciphertext",
      issuer: identity_binding.issuer,
      realm: "ORG",
      client_id: "base-org-ww",
      return_target: "/settings",
      initiating_generation: 0,
      state_id: RpBaseOrgStepUpStateStatus::PENDING,
      expires_at: now + 1.minute,
    )
    transition = RpBaseOrgStepUpStateTransition.create!(
      owner: state,
      from_state_id: RpBaseOrgStepUpStateStatus::PENDING,
      to_state_id: RpBaseOrgStepUpStateStatus::DISPATCHING,
      reason_code: "dispatch_started",
      occurred_at: now,
    )

    assert_raises(ActiveRecord::DeleteRestrictionError) { state.destroy! }
    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        RpBaseOrgRecord.transaction(requires_new: true) { state.delete }
      end
    assert_instance_of PG::RestrictViolation, error.cause
    assert RpBaseOrgStepUpStateTransition.exists?(transition.id)
  end

  test "audit delivery attempts prevent deleting their outbox in Active Record and PostgreSQL" do
    outbox = RpBaseOrgStepUpAuditOutbox.create!(
      event_uuid: SecureRandom.uuid,
      event_type: "step_up.requested",
      realm: "ORG",
      client_id: "base-org-ww",
      subject_ref: "subject-ref",
      context_ref: "a" * 21,
      reason_code: "requested",
      payload: { rp_state_ref: "rp-state", return_target_kind: "relative" },
      occurred_at: Time.current,
      delivery_state: RpBaseOrgStepUpAuditOutboxDeliveryState.find(
        RpBaseOrgStepUpAuditOutboxDeliveryState::PENDING,
      ),
    )
    attempt = RpBaseOrgStepUpAuditOutboxAttempt.create!(
      outbox: outbox,
      attempt_number: 1,
      attempted_at: Time.current,
      outcome: "failed",
      failure_code: "delivery_failed",
    )

    assert_raises(ActiveRecord::DeleteRestrictionError) { outbox.destroy! }
    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        RpBaseOrgRecord.transaction(requires_new: true) { outbox.delete }
      end
    assert_instance_of PG::RestrictViolation, error.cause
    assert RpBaseOrgStepUpAuditOutboxAttempt.exists?(attempt.id)
  end
end
