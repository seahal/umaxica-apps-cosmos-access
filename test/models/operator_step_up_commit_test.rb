# frozen_string_literal: true

require "test_helper"

class OperatorStepUpCommitTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(operator_tokens operator_device_sessions)

  test "commit attribution survives authorization transaction purge and follows root retention" do
    root = operator_tokens(:one)
    now = OperatorOidcAuthorizationTransaction.database_now
    grant = OpOrgGrant.create!(
      authentication_epoch: 0,
      operator_token_id: root.id,
      device_session_id: root.device_session_id,
      oidc_client_id: "base-org-ww",
      oidc_scope: "openid",
      oidc_jti: "00000000-0000-4000-8000-000000000002",
      oidc_nonce: "step-up-test-nonce",
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
      state: "step-up-state",
      nonce: "step-up-nonce",
      pkce: { code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM", code_challenge_method: "S256" },
      login_challenge: "step-up-login-challenge",
      login_challenge_expires_at: now + 1.minute,
      expires_at: now + 15.minutes,
      now: now,
    )
    context = OperatorStepUpContext.create!(
      public_id: "123456789abcdefghijkl",
      oidc_authorization_transaction: authorization,
      grant: grant,
      bound_subject: "step-up-subject",
      requested_acr: "https://visa.umaxica.app/acr/reauthentication",
      state: OperatorStepUpContextState.find(OperatorStepUpContextState::PENDING),
      expires_at: authorization.expires_at,
    )
    # Model preflight is tested separately; these writes must reach the real unique indexes.
    assert_raises(ActiveRecord::RecordNotUnique) do
      OperatorStepUpContext.transaction(requires_new: true) do
        OperatorStepUpContext.new(
          public_id: "223456789abcdefghijkl",
          oidc_authorization_transaction: authorization,
          grant: grant,
          bound_subject: "step-up-subject",
          requested_acr: "https://visa.umaxica.app/acr/reauthentication",
          state: OperatorStepUpContextState.find(OperatorStepUpContextState::PENDING),
          expires_at: authorization.expires_at,
        ).save!(validate: false)
      end
    end
    commit = OperatorStepUpCommit.create!(
      grant: grant,
      root_token: root,
      context_ref: context.public_id,
      verified_method: "passkey",
      committed_at: now,
    )
    assert_raises(ActiveRecord::RecordNotUnique) do
      OperatorStepUpCommit.transaction(requires_new: true) do
        OperatorStepUpCommit.new(
          grant: grant,
          root_token: root,
          context_ref: context.public_id,
          verified_method: "totp",
          committed_at: now + 1.second,
        ).save!(validate: false)
      end
    end
    transition = OperatorStepUpContextTransition.create!(
      owner: context,
      from_state: OperatorStepUpContextState.find(OperatorStepUpContextState::PENDING),
      to_state: OperatorStepUpContextState.find(OperatorStepUpContextState::COMMITTED),
      reason_code: "completed",
      occurred_at: now,
    )
    assert_raises(ActiveRecord::RecordNotUnique) do
      OperatorStepUpContextTransition.transaction(requires_new: true) do
        OperatorStepUpContextTransition.new(
          owner: context,
          from_state: OperatorStepUpContextState.find(OperatorStepUpContextState::PENDING),
          to_state: OperatorStepUpContextState.find(OperatorStepUpContextState::COMMITTED),
          reason_code: "completed",
          occurred_at: now + 1.second,
        ).save!(validate: false)
      end
    end

    authorization.update_columns(expires_at: now - OidcAuthorizationTransactionable::RETENTION_PERIOD)
    OidcAuthorizationTransactionPurger.call(now: now)

    assert_not OperatorOidcAuthorizationTransaction.exists?(authorization.id)
    assert_not OperatorStepUpContext.exists?(context.id)
    assert_not OperatorStepUpContextTransition.exists?(transition.id)
    assert_equal "passkey", commit.reload.verified_method

    root.delete

    assert_not OperatorStepUpCommit.exists?(commit.id)
  end

  test "a commit cannot store a method outside the closed set" do
    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        OperatorStepUpCommit.insert!(
          {
            grant_id: -1,
            root_token_id: -1,
            context_ref: "123456789abcdefghijkl",
            verified_method: "password",
            committed_at: Time.utc(2026, 11, 3, 12),
          },
        )
      end

    assert_includes error.message, "chk_operator_step_up_commits_method"
  end
end
