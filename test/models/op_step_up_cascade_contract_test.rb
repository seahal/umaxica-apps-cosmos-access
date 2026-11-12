# frozen_string_literal: true

require "test_helper"

class OpStepUpCascadeContractTest < ActiveSupport::TestCase
  setup do
    I18n.backend.store_translations(
      :en,
      activerecord: {
        attributes: {
          client_step_up_context: { transitions: "transitions" },
          operator_step_up_context: { transitions: "transitions" },
          client_step_up_audit_outbox: { attempts: "attempts" },
          operator_step_up_audit_outbox: { attempts: "attempts" },
        },
      },
    )
  end

  test "APP context deletion removes its transient transition rows" do
    context = app_context_with_transition
    transition_id = ClientStepUpContextTransition.find_by!(owner_id: context.id).id

    assert I18n.with_locale(:en) { context.destroy }, "APP context deletion should follow its database cascade contract"

    assert_not ClientStepUpContext.exists?(context.id)
    assert_not ClientStepUpContextTransition.exists?(transition_id)
  end

  test "ORG context deletion removes its transient transition rows" do
    context = org_context_with_transition
    transition_id = OperatorStepUpContextTransition.find_by!(owner_id: context.id).id

    assert I18n.with_locale(:en) { context.destroy }, "ORG context deletion should follow its database cascade contract"

    assert_not OperatorStepUpContext.exists?(context.id)
    assert_not OperatorStepUpContextTransition.exists?(transition_id)
  end

  test "APP outbox deletion removes its delivery attempt rows" do
    outbox = app_outbox_with_attempt
    attempt_id = ClientStepUpAuditOutboxAttempt.find_by!(outbox_id: outbox.id).id

    assert I18n.with_locale(:en) { outbox.destroy }, "APP outbox deletion should follow its database cascade contract"

    assert_not ClientStepUpAuditOutbox.exists?(outbox.id)
    assert_not ClientStepUpAuditOutboxAttempt.exists?(attempt_id)
  end

  test "ORG outbox deletion removes its delivery attempt rows" do
    outbox = org_outbox_with_attempt
    attempt_id = OperatorStepUpAuditOutboxAttempt.find_by!(outbox_id: outbox.id).id

    assert I18n.with_locale(:en) { outbox.destroy }, "ORG outbox deletion should follow its database cascade contract"

    assert_not OperatorStepUpAuditOutbox.exists?(outbox.id)
    assert_not OperatorStepUpAuditOutboxAttempt.exists?(attempt_id)
  end

  private

  def app_context_with_transition
    root = client_tokens(:one)
    now = ClientOidcAuthorizationTransaction.database_now
    grant = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token_id: root.id,
      oidc_client_id: "base-app-ww",
      oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: "cascade-contract-app-nonce",
      oidc_auth_time: now,
      refresh_token_expires_at: now + 10.minutes,
    )
    authorization = ClientOidcAuthorizationTransaction.create_transaction!(
      surface: "app",
      intent: "step_up",
      client_id: "base-app-ww",
      redirect_uri: "https://base.example.test/step-up/callback",
      response_type: "code",
      scope: "openid",
      state: "cascade-app-state",
      nonce: "cascade-app-nonce",
      code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      code_challenge_method: "S256",
      login_challenge: "cascade-app-login-challenge",
      login_challenge_expires_at: now + 1.minute,
      expires_at: now + 15.minutes,
      now: now,
    )
    context = ClientStepUpContext.create!(
      public_id: "123456789abcdefghijkl",
      oidc_authorization_transaction: authorization,
      grant: grant,
      bound_subject: "cascade-app-subject",
      requested_acr: "https://visa.umaxica.app/acr/reauthentication",
      state: ClientStepUpContextState.find(ClientStepUpContextState::PENDING),
      expires_at: authorization.expires_at,
    )
    context.transitions.create!(
      from_state: ClientStepUpContextState.find(ClientStepUpContextState::PENDING),
      to_state: ClientStepUpContextState.find(ClientStepUpContextState::COMMITTED),
      reason_code: "completed",
      occurred_at: now,
    )
    context
  end

  def org_context_with_transition
    root = operator_tokens(:one)
    now = OperatorOidcAuthorizationTransaction.database_now
    grant = OpOrgGrant.create!(
      authentication_epoch: 0,
      operator_token_id: root.id,
      oidc_client_id: "base-org-ww",
      oidc_scope: "openid",
      oidc_jti: SecureRandom.uuid,
      oidc_nonce: "cascade-contract-org-nonce",
      oidc_auth_time: now,
      refresh_token_expires_at: now + 10.minutes,
    )
    authorization = OperatorOidcAuthorizationTransaction.create_transaction!(
      surface: "org",
      intent: "step_up",
      client_id: "base-org-ww",
      redirect_uri: "https://base.example.test/step-up/callback",
      response_type: "code",
      scope: "openid",
      state: "cascade-org-state",
      nonce: "cascade-org-nonce",
      code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM",
      code_challenge_method: "S256",
      login_challenge: "cascade-org-login-challenge",
      login_challenge_expires_at: now + 1.minute,
      expires_at: now + 15.minutes,
      now: now,
    )
    context = OperatorStepUpContext.create!(
      public_id: "123456789abcdefghijkl",
      oidc_authorization_transaction: authorization,
      grant: grant,
      bound_subject: "cascade-org-subject",
      requested_acr: "https://visa.umaxica.app/acr/reauthentication",
      state: OperatorStepUpContextState.find(OperatorStepUpContextState::PENDING),
      expires_at: authorization.expires_at,
    )
    context.transitions.create!(
      from_state: OperatorStepUpContextState.find(OperatorStepUpContextState::PENDING),
      to_state: OperatorStepUpContextState.find(OperatorStepUpContextState::COMMITTED),
      reason_code: "completed",
      occurred_at: now,
    )
    context
  end

  def app_outbox_with_attempt
    outbox = ClientStepUpAuditOutbox.create!(
      event_uuid: SecureRandom.uuid,
      event_type: "step_up.requested",
      realm: "APP",
      client_id: "base-app-ww",
      subject_ref: "subject-ref",
      context_ref: "123456789abcdefghijkl",
      reason_code: "requested",
      payload: { rp_state_ref: "rp-state", return_target_kind: "relative" },
      occurred_at: Time.current,
      delivery_state: ClientStepUpAuditOutboxDeliveryState.find(ClientStepUpAuditOutboxDeliveryState::PENDING),
    )
    outbox.attempts.create!(
      attempt_number: 1,
      attempted_at: Time.current,
      outcome: "failed",
      failure_code: "delivery_failed",
    )
    outbox
  end

  def org_outbox_with_attempt
    outbox = OperatorStepUpAuditOutbox.create!(
      event_uuid: SecureRandom.uuid,
      event_type: "step_up.requested",
      realm: "ORG",
      client_id: "base-org-ww",
      subject_ref: "subject-ref",
      context_ref: "123456789abcdefghijkl",
      reason_code: "requested",
      payload: { rp_state_ref: "rp-state", return_target_kind: "relative" },
      occurred_at: Time.current,
      delivery_state: OperatorStepUpAuditOutboxDeliveryState.find(OperatorStepUpAuditOutboxDeliveryState::PENDING),
    )
    outbox.attempts.create!(
      attempt_number: 1,
      attempted_at: Time.current,
      outcome: "failed",
      failure_code: "delivery_failed",
    )
    outbox
  end
end
