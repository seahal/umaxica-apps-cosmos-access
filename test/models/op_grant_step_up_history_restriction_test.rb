# frozen_string_literal: true

require "test_helper"

class OpGrantStepUpHistoryRestrictionTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(client_tokens operator_tokens client_device_sessions operator_device_sessions)

  [
    [OpAppGrant, ClientOidcAuthorizationTransaction, ClientStepUpContext, ClientStepUpContextState,
     ClientStepUpCommit, "app", "app-client", :client_token_id,],
    [OpOrgGrant, OperatorOidcAuthorizationTransaction, OperatorStepUpContext, OperatorStepUpContextState,
     OperatorStepUpCommit, "org", "org-client", :operator_token_id,],
  ].each do |grant_model, authorization_model, context_model, state_model, commit_model, realm, client_id, token_key|
    [:context, :commit].each do |history_kind|
      test "#{realm} grant cannot be destroyed while #{history_kind} refers to it" do
        now = grant_model.database_now
        token = (token_key == :client_token_id) ? client_tokens(:one) : operator_tokens(:one)
        grant = grant_model.create!(
          token_key => token.id, :device_session_id => token.device_session_id,
          :authentication_epoch => 0, :oidc_client_id => client_id,
        )
        history =
          if history_kind == :context
            authorization = authorization_model.create_transaction!(
              surface: realm, intent: "step_up", client_id: client_id, redirect_uri: "https://example.com/callback",
              response_type: "code", scope: "openid", state: "state", nonce: "nonce",
              pkce: { code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM", code_challenge_method: "S256" },
              login_challenge: SecureRandom.base58(32), login_challenge_expires_at: now + 1.minute,
              expires_at: now + 15.minutes,
            )
            context_model.create!(
              public_id: PublicId.generate, oidc_authorization_transaction: authorization, grant: grant,
              bound_subject: "historical-subject", requested_acr: "https://visa.umaxica.app/acr/reauthentication",
              state: state_model.find(state_model::PENDING), expires_at: authorization.expires_at,
            )
          else
            commit_model.create!(
              grant: grant, root_token: token, context_ref: PublicId.generate,
              verified_method: "passkey", committed_at: now,
            )
          end

        grant = grant_model.includes(:logout_hint).find(grant.id)

        grant_model.transaction(requires_new: true) { assert_not grant.destroy }

        assert_predicate grant.reload, :persisted?
        assert_predicate history.reload, :persisted?
        [:en, :ja].each do |locale|
          I18n.with_locale(locale) { assert_not_empty grant.errors.full_messages }
        end
        assert_raises(ActiveRecord::InvalidForeignKey) do
          grant_model.transaction(requires_new: true) { grant_model.where(id: grant.id).delete_all }
        end
        assert_predicate history.reload, :persisted?
      end
    end
  end
end
