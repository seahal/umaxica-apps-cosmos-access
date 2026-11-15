# frozen_string_literal: true

require "test_helper"

class StepUpContextTransitionWriterTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(
    client_tokens client_device_sessions operator_tokens operator_device_sessions
    client_token_kinds client_token_statuses client_token_binding_methods client_token_dbsc_statuses
    operator_token_kinds operator_token_statuses operator_token_binding_methods operator_token_dbsc_statuses
  )

  test "client cancellation writes one APP-owned transition and changes the context state" do
    root = ClientToken.find(ActiveRecord::FixtureSet.identify(:one))
    now = ClientOidcAuthorizationTransaction.database_now
    grant = OpAppGrant.create!(
      authentication_epoch: 0,
      client_token_id: root.id,
      device_session_id: root.device_session_id,
      oidc_client_id: "transition-app-client",
      oidc_scope: "openid",
      refresh_token_expires_at: now + 10.minutes,
    )
    authorization = ClientOidcAuthorizationTransaction.create_transaction!(
      surface: "app",
      intent: "step_up",
      client_id: "transition-app-client",
      redirect_uri: "https://app.example/callback",
      response_type: "code",
      scope: "openid",
      state: "transition-state",
      nonce: "transition-nonce",
      pkce: { code_challenge: "A" * 43, code_challenge_method: "S256" },
      login_challenge: "transition-app-login",
      login_challenge_expires_at: now + 1.minute,
      expires_at: now + 10.minutes,
      now:,
    )
    context = ClientStepUpContext.create!(
      public_id: PublicId.generate,
      oidc_authorization_transaction: authorization,
      grant: grant,
      bound_subject: "client-subject",
      requested_acr: "https://visa.umaxica.app/acr/reauthentication",
      state: ClientStepUpContextState.find(ClientStepUpContextState::PENDING),
      expires_at: authorization.expires_at,
    )

    assert ClientStepUpContextTransitionWriter.call!(
      context:,
      to_state_id: ClientStepUpContextState::CANCELLED,
      reason_code: "user_cancelled",
    )

    assert_equal ClientStepUpContextState::CANCELLED, context.reload.state_id
    transition = ClientStepUpContextTransition.where(owner: context).sole

    assert_equal ClientStepUpContextState::PENDING, transition.from_state_id
    assert_equal ClientStepUpContextState::CANCELLED, transition.to_state_id
    assert_equal "user_cancelled", transition.reason_code
  end

  test "operator cancellation writes one ORG-owned transition and changes the context state" do
    root = OperatorToken.find(ActiveRecord::FixtureSet.identify(:one))
    now = OperatorOidcAuthorizationTransaction.database_now
    grant = OpOrgGrant.create!(
      authentication_epoch: 0,
      operator_token_id: root.id,
      device_session_id: root.device_session_id,
      oidc_client_id: "transition-org-client",
      oidc_scope: "openid",
      refresh_token_expires_at: now + 10.minutes,
    )
    authorization = OperatorOidcAuthorizationTransaction.create_transaction!(
      surface: "org",
      intent: "step_up",
      client_id: "transition-org-client",
      redirect_uri: "https://org.example/callback",
      response_type: "code",
      scope: "openid",
      state: "transition-state",
      nonce: "transition-nonce",
      pkce: { code_challenge: "B" * 43, code_challenge_method: "S256" },
      login_challenge: "transition-org-login",
      login_challenge_expires_at: now + 1.minute,
      expires_at: now + 10.minutes,
      now:,
    )
    context = OperatorStepUpContext.create!(
      public_id: PublicId.generate,
      oidc_authorization_transaction: authorization,
      grant: grant,
      bound_subject: "operator-subject",
      requested_acr: "https://visa.umaxica.app/acr/reauthentication",
      state: OperatorStepUpContextState.find(OperatorStepUpContextState::PENDING),
      expires_at: authorization.expires_at,
    )

    assert OperatorStepUpContextTransitionWriter.call!(
      context:,
      to_state_id: OperatorStepUpContextState::CANCELLED,
      reason_code: "user_cancelled",
    )

    assert_equal OperatorStepUpContextState::CANCELLED, context.reload.state_id
    transition = OperatorStepUpContextTransition.where(owner: context).sole

    assert_equal OperatorStepUpContextState::PENDING, transition.from_state_id
    assert_equal OperatorStepUpContextState::CANCELLED, transition.to_state_id
    assert_equal "user_cancelled", transition.reason_code
  end
end
