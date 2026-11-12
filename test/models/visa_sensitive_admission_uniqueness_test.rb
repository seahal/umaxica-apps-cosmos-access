# frozen_string_literal: true

require "test_helper"

class VisaSensitiveAdmissionUniquenessTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(client_tokens operator_tokens client_device_sessions operator_device_sessions)

  [
    [ClientVisaSensitiveAdmission, ClientOidcAuthorizationTransaction, ClientStepUpCeremonyTransaction,
     ClientAuthAdmissionBinding, "app", "base-app-ww", :client_tokens,],
    [OperatorVisaSensitiveAdmission, OperatorOidcAuthorizationTransaction, OperatorStepUpCeremonyTransaction,
     OperatorAuthAdmissionBinding, "org", "base-org-ww", :operator_tokens,],
  ].each do |model, parent_model, ticket_model, binding_model, realm, client_id, fixture_name|
    test "#{realm} sensitive admissions cannot reuse the OIDC request, ceremony or admission binding" do
      now = model.database_now
      token = (fixture_name == :client_tokens) ? client_tokens(:one) : operator_tokens(:one)
      references =
        2.times.map do
          parent = parent_model.create_transaction!(
            surface: realm, intent: "step_up", client_id: client_id, redirect_uri: "https://example.com/callback",
            response_type: "code", scope: "openid", state: "state", nonce: "nonce",
            code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM", code_challenge_method: "S256",
            login_challenge: SecureRandom.base58(32), login_challenge_expires_at: now + 15.minutes,
            expires_at: now + 15.minutes,
          )
          ticket = ticket_model.create_transaction!(
            actor_ref: "historical-actor", session_ref: token.public_id, required_scope: "settings_passkey",
            required_aal: "none", allowed_methods: ["passkey"], purpose: "credential_registration",
            step_up_required: false,
          )
          binding = binding_model.create!(
            entry_ref: SecureRandom.uuid, purpose: "credential_registration_handoff", entry_intent: "not_applicable",
            step_up_ceremony_transaction: ticket, base_token: token, base_browser_digest: SecureRandom.hex(32),
            expires_at: now + 15.minutes, curfew_at: now + 15.minutes, created_at: now, updated_at: now,
          )
          {
            oidc_authorization_transaction_id: parent.id,
            step_up_ceremony_transaction_id: ticket.id,
            auth_admission_binding_id: binding.id,
          }
        end
      attributes = {
        public_ref: PublicId.generate,
        realm: realm,
        client_id: client_id,
        actor_subject: "historical-actor",
        grant_sid: "grant-sid",
        rp_session_ref: "rp-session",
        rp_session_expires_at: now + 15.minutes,
        browser_binding_digest: SecureRandom.hex(32),
        purpose: "passkey_registration",
        provider: "none",
        event_jti: SecureRandom.uuid,
        event_auth_time: now.to_i,
        event_acr: "reauthentication",
        event_amr: ["passkey"],
        status: "issued",
        expires_at: now + 5.minutes,
        created_at: now,
        updated_at: now,
      }
      first = model.create!(attributes.merge(references.first))
      %i(oidc_authorization_transaction_id step_up_ceremony_transaction_id auth_admission_binding_id).each do |field|
        candidate_attributes = attributes.merge(references.last).merge(
          :public_ref => PublicId.generate,
          field => first[field],
        )
        candidate = model.new(candidate_attributes)

        assert_not candidate.valid?
        assert candidate.errors.of_kind?(field, :taken)
        [:en, :ja].each do |locale|
          I18n.with_locale(locale) { assert_raises(ActiveRecord::RecordInvalid) { candidate.save! } }
        end
        assert_raises(ActiveRecord::RecordNotUnique) do
          model.transaction(requires_new: true) { model.insert_all!([candidate_attributes]) }
        end
      end
      separate = model.create!(attributes.merge(references.last).merge(public_ref: PublicId.generate))

      assert_predicate separate, :persisted?
    end
  end
end
