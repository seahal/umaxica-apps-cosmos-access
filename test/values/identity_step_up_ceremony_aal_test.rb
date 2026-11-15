# typed: false
# frozen_string_literal: true

require "test_helper"

# Legacy AAL labels remain observable wire/storage labels only. The explicit requirement and
# evidence fields are the authority, and an explicit legacy demand is refused at issuance.
class IdentityStepUpCeremonyAalTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "legacy AAL demand is refused and Access cannot sign a Governance grant" do
    now = Time.current
    claims = {
      "typ" => IdentityStepUpCeremonyGrant::TOKEN_TYPE,
      "iss" => IdentityStepUpCeremonyContract.acme_issuer("app"),
      "aud" => IdentityStepUpCeremonyContract.sign_audience("app"),
      "purpose" => IdentityStepUpCeremonyGrant::PURPOSE,
      "surface" => "app",
      "actor_ref" => "actor-public-id",
      "session_ref" => "session-public-id",
      "transaction_id" => SecureRandom.uuid,
      "jti" => SecureRandom.uuid,
      "required_scope" => "settings_email",
      "required_aal" => StepUpRequirement::NO_AAL,
      "step_up_required" => true,
      "user_verification_required" => false,
      "full_reauthentication_required" => false,
      "phishing_resistant_required" => false,
      "audience" => "step_up:app",
      "token_binding" => "session-public-id",
      "require_session_binding" => true,
      "allowed_methods" => %w(totp passkey),
      "iat" => now.to_i,
      "exp" => (now + 5.minutes).to_i,
    }

    legacy_error =
      assert_raises(IdentityStepUpCeremonyContract::Error) do
        IdentityStepUpCeremonyGrant.new(claims.merge("required_aal" => "aal2"), now: now)
      end
    assert_includes legacy_error.message, "legacy AAL requirements are unsupported"

    signing_error =
      assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
        IdentityStepUpCeremonyGrant.issue(
          claims,
          issuer_id: IdentityStepUpCeremonyContract.acme_issuer_id("app"),
          now: now,
        )
      end
    assert_includes signing_error.message, "surface:BASE_APP"
  end

  def issue_result(aal: "aal1", user_verified: false, phishing_resistant: false)
    IdentityStepUpCeremonyResultIssuer.issue!(
      surface: "app", actor_ref: "actor-public-id", session_ref: "session-public-id",
      transaction_id: SecureRandom.uuid, grant_jti: SecureRandom.uuid, scope: "settings_email",
      aal: aal, method: "totp", phishing_resistant: phishing_resistant,
      user_verified: user_verified, full_reauthentication: false, credential_ref: "credential-public-id",
      challenge_id: SecureRandom.uuid, expires_at: 5.minutes.from_now,
    )
  end

  def decode_result(token)
    IdentityStepUpCeremonyResult.decode(
      token,
      issuer_id: IdentityStepUpCeremonyContract.sign_issuer_id("app"),
    )
  end

  test "a result exposes its legacy label without making it an authority" do
    result = decode_result(issue_result(aal: "aal2"))

    assert_equal :aal2, result.achieved_aal
    assert_not_respond_to result, :aal_required?
    assert_not result["user_verified"]
  end

  test "explicit evidence survives independently of the legacy label" do
    result = decode_result(issue_result(aal: "none", user_verified: true, phishing_resistant: true))

    assert_equal "none", result["aal"]
    assert result["user_verified"]
    assert result["phishing_resistant"]
    assert_equal "credential-public-id", result["credential_ref"]
  end
end
