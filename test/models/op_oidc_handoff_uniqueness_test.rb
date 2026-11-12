# frozen_string_literal: true

require "test_helper"

class OpOidcHandoffUniquenessTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "cancellation handoff references and digests are unique within each realm" do
    [[ClientOidcAuthorizationTransaction, "app", "core-app-jp"],
     [OperatorOidcAuthorizationTransaction, "org", "core-org-jp"],].each do |model, surface, client_id|
      [:cancellation_handoff_ref, :cancellation_handoff_digest].each do |field|
        now = model.database_now
        rows =
          2.times.map do
            model.create_transaction!(
              surface: surface, intent: "sign_in", client_id: client_id, redirect_uri: "https://example.com/callback",
              response_type: "code", scope: "openid", state: "state", nonce: "nonce",
              code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM", code_challenge_method: "S256",
              login_challenge: SecureRandom.base58(32), login_challenge_expires_at: now + 1.minute,
              expires_at: now + 1.minute,
            )
          end
        attributes = { field => ((field == :cancellation_handoff_ref) ? SecureRandom.uuid : SecureRandom.hex(32)) }
        attributes[:cancellation_handoff_ciphertext] = "ciphertext" if field == :cancellation_handoff_ref
        rows.first.update_columns(attributes)
        rows.last.assign_attributes(attributes)

        assert_not rows.last.valid?
        assert rows.last.errors.of_kind?(field, :taken)
        assert_raises(ActiveRecord::RecordNotUnique) do
          model.transaction(requires_new: true) { rows.last.update_columns(attributes) }
        end
      end
    end
  end
end
