# frozen_string_literal: true

require "test_helper"

class ClientSignUpResultDigestUniquenessTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "sign-up result digests are unique while absent results may coexist" do
    now = ClientSignUpFlow.database_now
    rows =
      2.times.map do
        parent = ClientOidcAuthorizationTransaction.create_transaction!(
          surface: "app", intent: "sign_up", client_id: "core-app-jp", redirect_uri: "https://example.com/callback",
          response_type: "code", scope: "openid", state: "state", nonce: "nonce",
          code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM", code_challenge_method: "S256",
          login_challenge: SecureRandom.base58(32), login_challenge_expires_at: now + 15.minutes,
          expires_at: now + 15.minutes,
        )
        binding = ClientAuthAdmissionBinding.create!(
          entry_ref: SecureRandom.uuid, purpose: "authentication_handoff", entry_intent: "sign_up",
          authorization_transaction: parent, base_browser_digest: SecureRandom.hex(32),
          expires_at: now + 15.minutes, curfew_at: now + 15.minutes, created_at: now, updated_at: now,
        )
        attached, raw_sid = ClientAuthCeremonySession.issue!
        binding.attach_auth_session!(auth_session: attached, confirmation_ref: SecureRandom.uuid)
        binding.confirm_base!(base_token: nil, browser_digest: binding.base_browser_digest)
        admitted, = ClientAuthCeremonySession.rotate_and_admit!(
          admission_purpose: "authentication_handoff", previous_raw_sid: raw_sid,
          authorization_transaction_ref: parent.transaction_id,
        )
        binding.redeem!(auth_session: attached, admitted_auth_session: admitted)
        ClientSignUpFlow.create!(
          auth_admission_binding: binding, step: "start", entry_method: "email",
          issued_at: now, expires_at: now + 15.minutes, nonce_digest: SecureRandom.hex(32),
        )
      end

    assert_nil rows.first.result_digest
    assert_nil rows.last.result_digest
    result = {
      result_digest: SecureRandom.hex(32),
      result_generation: 1,
      result_expires_at: now + 1.minute,
      principal_id: 123,
      authentication_method: "email",
      authentication_event_at: now,
    }
    rows.first.update_columns(result)
    rows.last.assign_attributes(result)

    assert_not rows.last.valid?
    assert rows.last.errors.of_kind?(:result_digest, :taken)
    assert_raises(ActiveRecord::RecordNotUnique) do
      ClientSignUpFlow.transaction(requires_new: true) { rows.last.update_columns(result) }
    end
  end
end
