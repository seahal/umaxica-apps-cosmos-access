# frozen_string_literal: true

require "test_helper"

class IdentityCeremonyGrantIssuerContractTest < ActiveSupport::TestCase
  test "step-up grant issuance signs claims from the persisted transaction" do
    issuance_time = ClientStepUpCeremonyTransaction.database_now
    signed_claims = nil
    signed_issuer = nil
    signed_at = nil

    issuance =
      IdentityStepUpCeremonyGrant.stub(
        :issue,
        ->(claims, issuer_id:, now:) {
          signed_claims = claims
          signed_issuer = issuer_id
          signed_at = now
          "signed-step-up-grant"
        },
      ) do
        IdentityStepUpCeremonyGrantIssuer.issue!(
          surface: "app",
          actor_ref: "actor-public-id",
          session_ref: "session-public-id",
          required_scope: "settings_passkey",
          audience: "https://resource.example/passkeys",
          token_binding: "session-public-id",
          allowed_methods: ["passkey"],
          now: issuance_time,
        )
      end

    assert_instance_of ClientStepUpCeremonyTransaction, issuance.transaction
    assert_equal "actor-public-id", issuance.transaction.actor_ref
    assert_equal "session-public-id", issuance.transaction.session_ref
    assert_equal "settings_passkey", signed_claims.fetch("required_scope")
    assert_equal issuance.transaction.transaction_id, signed_claims.fetch("transaction_id")
    assert_equal issuance.transaction.grant_jti, signed_claims.fetch("jti")
    assert_equal IdentityStepUpCeremonyContract.acme_issuer_id("app"), signed_issuer
    assert_equal issuance_time, signed_at
    assert_equal "signed-step-up-grant", issuance.grant
  end

  test "social grant issuance signs claims from its realm-local transaction" do
    issuance_time = ClientSocialCeremonyTransaction.database_now
    signed_claims = nil
    signed_issuer = nil

    issuance =
      IdentitySocialCeremonyGrant.stub(
        :issue,
        ->(claims, issuer_id:, now:) {
          signed_claims = claims
          signed_issuer = issuer_id
          "signed-social-grant"
        },
      ) do
        IdentitySocialCeremonyGrantIssuer.issue!(
          surface: "app",
          actor_ref: "actor-public-id",
          session_ref: "session-public-id",
          operation: "link",
          provider: "google",
          provider_subject_ref: "google-subject",
          provider_subject_digest: Digest::SHA256.hexdigest("google:google-subject"),
          now: issuance_time,
        )
      end

    assert_instance_of ClientSocialCeremonyTransaction, issuance.transaction
    assert_equal "actor-public-id", signed_claims.fetch("actor_ref")
    assert_equal "session-public-id", signed_claims.fetch("session_ref")
    assert_equal "google", signed_claims.fetch("provider")
    assert_equal issuance.transaction.transaction_id, signed_claims.fetch("transaction_id")
    assert_equal issuance.transaction.grant_jti, signed_claims.fetch("jti")
    assert_equal IdentitySocialCeremonyContract.acme_issuer_id("app"), signed_issuer
    assert_equal "signed-social-grant", issuance.grant
  end

  test "passkey result issuance refuses a missing candidate before looking up a grant" do
    error =
      assert_raises(IdentityPasskeyCeremonyContract::Error) do
        IdentityPasskeyCeremonyResultIssuer.issue!(
          grant_token: "opaque-grant",
          candidate: nil,
          surface: "app",
          actor_ref: "actor-public-id",
          session_ref: "session-public-id",
          operation: "registration",
        )
      end

    assert_equal "candidate is required", error.message
  end
end
