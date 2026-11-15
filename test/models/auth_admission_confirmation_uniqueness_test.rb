# frozen_string_literal: true

require "test_helper"

class AuthAdmissionConfirmationUniquenessTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  [
    [ClientOidcAuthorizationTransaction, ClientAuthAdmissionBinding, ClientAuthCeremonySession, "app", "core-app-jp"],
    [OperatorOidcAuthorizationTransaction, OperatorAuthAdmissionBinding, OperatorAuthCeremonySession, "org",
     "core-org-jp",],
  ].each do |parent_model, binding_model, session_model, realm, client_id|
    test "#{realm} admission confirmation references are unique and absent references coexist" do
      now = binding_model.database_now
      bindings =
        2.times.map do
          parent = parent_model.create_transaction!(
            surface: realm, intent: "sign_in", client_id: client_id, redirect_uri: "https://example.com/callback",
            response_type: "code", scope: "openid", state: "state", nonce: "nonce",
            pkce: { code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM", code_challenge_method: "S256" },
            login_challenge: SecureRandom.base58(32), login_challenge_expires_at: now + 15.minutes,
            expires_at: now + 15.minutes,
          )
          binding_model.create!(
            entry_ref: SecureRandom.uuid, purpose: "authentication_handoff", entry_intent: "sign_in",
            authorization_transaction: parent, base_browser_digest: SecureRandom.hex(32),
            expires_at: now + 15.minutes, curfew_at: now + 15.minutes, created_at: now, updated_at: now,
          )
        end

      assert_nil bindings.first.confirmation_ref
      assert_nil bindings.last.confirmation_ref
      first_session, = session_model.issue!
      second_session, = session_model.issue!
      reference = SecureRandom.uuid
      bindings.first.attach_auth_session!(auth_session: first_session, confirmation_ref: reference)
      duplicate = bindings.last
      duplicate.assign_attributes(
        auth_ceremony_session_id: second_session.id, confirmation_ref: reference,
        status_id: AuthAdmissionBinding::ATTACHED_STATUS_ID,
      )

      assert_not duplicate.valid?
      assert duplicate.errors.of_kind?(:confirmation_ref, :taken)
      assert_raises(ActiveRecord::RecordNotUnique) do
        binding_model.transaction(requires_new: true) do
          duplicate.update_columns(
            auth_ceremony_session_id: second_session.id, confirmation_ref: reference,
            status_id: AuthAdmissionBinding::ATTACHED_STATUS_ID,
          )
        end
      end
      duplicate.reload

      assert_nil duplicate.confirmation_ref
      [:en, :ja].each do |locale|
        I18n.with_locale(locale) do
          assert_raises(ActiveRecord::RecordInvalid) do
            duplicate.attach_auth_session!(auth_session: second_session, confirmation_ref: reference)
          end
        end
        assert_nil duplicate.reload.confirmation_ref
      end
      duplicate.attach_auth_session!(auth_session: second_session, confirmation_ref: SecureRandom.uuid)

      assert_predicate duplicate.reload, :attached?
    end
  end
end
