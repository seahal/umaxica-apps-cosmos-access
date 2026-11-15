# frozen_string_literal: true

require "test_helper"

class OpStepUpPersistenceUniquenessTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(client_tokens client_device_sessions operator_tokens operator_device_sessions)

  test "each realm rejects duplicate context identities and authorization owners before saving" do
    [
      ["app", client_tokens(:one), OpAppGrant, :client_token_id,
       ClientOidcAuthorizationTransaction, ClientStepUpContext, "base-app-ww",],
      ["org", operator_tokens(:one), OpOrgGrant, :operator_token_id,
       OperatorOidcAuthorizationTransaction, OperatorStepUpContext, "base-org-ww",],
    ].each do |surface, root, grant_model, root_key, parent_model, context_model, client_id|
      grant = grant_model.create!(
        root_key => root.id, :device_session_id => root.device_session_id,
        :authentication_epoch => 0, :oidc_client_id => client_id,
      )
      now = parent_model.database_now
      authorizations =
        Array.new(2) do |number|
          parent_model.create_transaction!(
            surface: surface, intent: "step_up", client_id: client_id,
            redirect_uri: "https://base.example.test/step-up/callback", response_type: "code", scope: "openid",
            state: "context-#{number}", nonce: "nonce-#{number}", pkce: { code_challenge: "a" * 43, code_challenge_method: "S256" }, login_challenge: "#{surface}-challenge-#{number}",
            login_challenge_expires_at: now + 1.minute, expires_at: now + 15.minutes, now: now,
          )
        end
      attributes = {
        public_id: "a" * 21,
        oidc_authorization_transaction: authorizations.first,
        grant: grant,
        bound_subject: "subject",
        requested_acr: OidcAuthorizeRequestResolver::STEP_UP_ACR,
        state_id: 10,
        expires_at: now + 15.minutes,
      }
      original = context_model.create!(attributes)
      duplicate_identity = context_model.new(attributes.merge(oidc_authorization_transaction: authorizations.last))

      assert_not duplicate_identity.save
      assert duplicate_identity.errors.of_kind?(:public_id, :taken)
      assert_raises(ActiveRecord::RecordNotUnique) do
        context_model.transaction(requires_new: true) { duplicate_identity.save!(validate: false) }
      end

      duplicate_owner = context_model.new(attributes.merge(public_id: "b" * 21))

      assert_not duplicate_owner.save
      assert duplicate_owner.errors.of_kind?(:oidc_authorization_transaction_id, :taken)
      assert_predicate original, :valid?
      assert_predicate context_model.create!(
        attributes.merge(public_id: "b" * 21, oidc_authorization_transaction: authorizations.last),
      ), :persisted?
    end
  end

  test "each realm preserves commit identity and transition target ownership through model validation" do
    [
      ["app", client_tokens(:one), OpAppGrant, :client_token_id,
       ClientOidcAuthorizationTransaction, ClientStepUpContext, ClientStepUpCommit,
       ClientStepUpContextTransition, "base-app-ww",],
      ["org", operator_tokens(:one), OpOrgGrant, :operator_token_id,
       OperatorOidcAuthorizationTransaction, OperatorStepUpContext, OperatorStepUpCommit,
       OperatorStepUpContextTransition, "base-org-ww",],
    ].each do |surface, root, grant_model, root_key, authorization_model, context_model,
               commit_model, transition_model, client_id|
      grant = grant_model.create!(
        root_key => root.id, :device_session_id => root.device_session_id,
        :authentication_epoch => 0, :oidc_client_id => client_id,
      )
      now = authorization_model.database_now
      contexts =
        Array.new(2) do |number|
          authorization = authorization_model.create_transaction!(
            surface: surface, intent: "step_up", client_id: client_id,
            redirect_uri: "https://base.example.test/step-up/callback", response_type: "code", scope: "openid",
            state: "context-#{number}", nonce: "nonce-#{number}", pkce: { code_challenge: "a" * 43, code_challenge_method: "S256" }, login_challenge: "#{surface}-challenge-#{number}",
            login_challenge_expires_at: now + 1.minute, expires_at: now + 15.minutes, now: now,
          )
          context_model.create!(
            public_id: "#{number}" * 21, oidc_authorization_transaction: authorization, grant: grant,
            bound_subject: "subject", requested_acr: OidcAuthorizeRequestResolver::STEP_UP_ACR,
            state_id: 10, expires_at: now + 15.minutes,
          )
        end
      commit_attributes = {
        grant: grant,
        root_token: root,
        context_ref: contexts.first.public_id,
        verified_method: "passkey",
        committed_at: now,
      }
      commit = commit_model.create!(commit_attributes)
      duplicate_commit = commit_model.new(commit_attributes.merge(verified_method: "totp"))

      assert_not duplicate_commit.save
      assert duplicate_commit.errors.of_kind?(:context_ref, :taken)
      assert_predicate commit, :valid?
      assert_predicate commit_model.create!(commit_attributes.merge(context_ref: contexts.last.public_id)), :persisted?

      transition_attributes = {
        owner: contexts.first, from_state_id: 10, to_state_id: 20, reason_code: "completed", occurred_at: now,
      }
      transition = transition_model.create!(transition_attributes)
      duplicate_transition = transition_model.new(transition_attributes.merge(occurred_at: now + 1.second))

      assert_not duplicate_transition.save
      assert duplicate_transition.errors.of_kind?(:to_state_id, :taken)
      assert_predicate transition, :valid?
      assert_predicate transition_model.create!(transition_attributes.merge(owner: contexts.last)), :persisted?
      assert_predicate transition_model.create!(
        transition_attributes.merge(to_state_id: 90, reason_code: "user_cancelled"),
      ), :persisted?
    end
  end
end
