# typed: false
# frozen_string_literal: true

require "test_helper"

class IdentityCredentialCandidateStoreTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "secret credential candidates retain their binding and become one-time on consume" do
    candidate = IdentitySecretCredentialCeremonyCandidateStore.store!(
      surface: "app",
      actor_ref: "secret-actor",
      session_ref: "secret-session",
      transaction_id: "secret-transaction",
      operation: "enrollment",
      password_digest: "secret-credential-digest",
      name: "primary",
      enabled: false,
      expires_at: 5.minutes.from_now,
    )

    fetched = IdentitySecretCredentialCeremonyCandidateStore.fetch!(candidate.ref)

    assert_equal "secret-actor", fetched.actor_ref
    assert_equal "secret-session", fetched.session_ref
    assert_equal "secret-transaction", fetched.transaction_id
    assert_equal "enrollment", fetched.operation
    assert_equal "primary", fetched.name
    assert_not fetched.enabled

    consumed = IdentitySecretCredentialCeremonyCandidateStore.consume!(candidate.ref)

    assert_equal candidate.ref, consumed.ref
    assert_raises(IdentitySecretCredentialCeremonyContract::Error) do
      IdentitySecretCredentialCeremonyCandidateStore.fetch!(candidate.ref)
    end
    assert_raises(IdentitySecretCredentialCeremonyContract::Error) do
      IdentitySecretCredentialCeremonyCandidateStore.consume!(candidate.ref)
    end
  end

  test "secret credential candidate deletion retires it and missing secrets fail closed" do
    candidate = IdentitySecretCredentialCeremonyCandidateStore.store!(
      surface: "org",
      actor_ref: "secret-delete-actor",
      session_ref: "secret-delete-session",
      transaction_id: "secret-delete-transaction",
      operation: "replacement",
      password_digest: "secret-credential-digest",
      name: "recovery",
      enabled: true,
      expires_at: 5.minutes.from_now,
    )

    assert IdentitySecretCredentialCeremonyCandidateStore.delete(candidate.ref)
    assert_raises(IdentitySecretCredentialCeremonyContract::Error) do
      IdentitySecretCredentialCeremonyCandidateStore.fetch!(candidate.ref)
    end
    assert_raises(IdentitySecretCredentialCeremonyContract::Error) do
      IdentitySecretCredentialCeremonyCandidateStore.store!(
        surface: "app",
        actor_ref: "secret-invalid-actor",
        session_ref: "secret-invalid-session",
        transaction_id: "secret-invalid-transaction",
        operation: "enrollment",
        password_digest: "",
        name: "primary",
        enabled: true,
        expires_at: 5.minutes.from_now,
      )
    end
  end

  test "expiring a persisted secret candidate closes its reference at the writer clock" do
    candidate = IdentitySecretCredentialCeremonyCandidateStore.store!(
      surface: "app",
      actor_ref: "secret-expiry-actor",
      session_ref: "secret-expiry-session",
      transaction_id: "secret-expiry-transaction",
      operation: "enrollment",
      password_digest: "secret-expiry-digest",
      name: "primary",
      enabled: true,
      expires_at: 5.minutes.from_now,
    )
    record = IdentitySecretCredentialCeremonyCandidate.find_by!(ref: candidate.ref)
    decision_time = IdentitySecretCredentialCeremonyCandidate.database_now

    assert_same record, record.expire!
    assert_in_delta decision_time.to_f, record.reload.expires_at.to_f, 0.1

    assert_raises(IdentitySecretCredentialCeremonyContract::Error) do
      IdentitySecretCredentialCeremonyCandidateStore.fetch!(record.ref)
    end
  end

  test "TOTP candidates retain their binding and become one-time on consume" do
    candidate = IdentityTotpCeremonyCandidateStore.store!(
      surface: "app",
      actor_ref: "totp-actor",
      session_ref: "totp-session",
      private_key: "totp-private-key",
      title: "Authenticator",
      last_otp_at: Time.current.to_i,
      expires_at: 5.minutes.from_now,
    )

    fetched = IdentityTotpCeremonyCandidateStore.fetch!(candidate.ref)

    assert_equal "totp-actor", fetched.actor_ref
    assert_equal "totp-session", fetched.session_ref
    assert_equal "totp-private-key", fetched.private_key
    assert_equal "Authenticator", fetched.title

    consumed = IdentityTotpCeremonyCandidateStore.consume!(candidate.ref)

    assert_equal candidate.ref, consumed.ref
    assert_raises(IdentityTotpCeremonyContract::Error) do
      IdentityTotpCeremonyCandidateStore.fetch!(candidate.ref)
    end
    assert_raises(IdentityTotpCeremonyContract::Error) do
      IdentityTotpCeremonyCandidateStore.consume!(candidate.ref)
    end
  end

  test "TOTP candidate deletion retires it and missing secrets fail closed" do
    candidate = IdentityTotpCeremonyCandidateStore.store!(
      surface: "org",
      actor_ref: "totp-delete-actor",
      session_ref: "totp-delete-session",
      private_key: "totp-delete-private-key",
      title: "Recovery authenticator",
      last_otp_at: Time.current.to_i,
      expires_at: 5.minutes.from_now,
    )

    assert IdentityTotpCeremonyCandidateStore.delete(candidate.ref)
    assert_raises(IdentityTotpCeremonyContract::Error) do
      IdentityTotpCeremonyCandidateStore.fetch!(candidate.ref)
    end
    assert_raises(IdentityTotpCeremonyContract::Error) do
      IdentityTotpCeremonyCandidateStore.store!(
        surface: "app",
        actor_ref: "totp-invalid-actor",
        session_ref: "totp-invalid-session",
        private_key: "",
        title: "Authenticator",
        last_otp_at: Time.current.to_i,
        expires_at: 5.minutes.from_now,
      )
    end
  end
end
