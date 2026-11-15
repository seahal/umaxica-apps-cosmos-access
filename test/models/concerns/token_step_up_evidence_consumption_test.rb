# typed: false
# frozen_string_literal: true

require "test_helper"

# Step-Up remains fail closed until Governance supplies the policy lookup. Existing evidence must
# remain unchanged when the required current authority is unavailable.
class TokenStepUpEvidenceConsumptionTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(client_tokens operator_tokens client_device_sessions operator_device_sessions)

  NOW = Time.zone.parse("2026-10-25 00:00:00")
  SCOPE = "settings_passkey"
  TARGET = "passkey-target-1"

  test "APP evidence is not consumed while Governance step-up policy is unavailable" do
    token = evidence_token(ClientToken.find(ActiveRecord::FixtureSet.identify(:one)))
    original_status = token.user_token_status_id
    original_deadline = token.discard_at

    assert_refused_and_kept(token, requirement(token))

    assert_equal original_status, token.user_token_status_id
    assert_equal original_deadline, token.discard_at
  end

  test "ORG evidence is not consumed while Governance step-up policy is unavailable" do
    token = evidence_token(OperatorToken.find(ActiveRecord::FixtureSet.identify(:one)), method: "passkey")
    original_status = token.staff_token_status_id
    original_deadline = token.discard_at

    assert_refused_and_kept(token, requirement(token))

    assert_equal original_status, token.staff_token_status_id
    assert_equal original_deadline, token.discard_at
  end

  test "evidence for another operation is refused and kept" do
    token = evidence_token(ClientToken.find(ActiveRecord::FixtureSet.identify(:one)))

    assert_refused_and_kept(token, requirement(token, scope: "settings_email"))
    assert_refused_and_kept(token, requirement(token, audience: "step_up:other"))
  end

  test "evidence for another target is refused and kept" do
    token = evidence_token(ClientToken.find(ActiveRecord::FixtureSet.identify(:one)))

    assert_refused_and_kept(token, requirement(token, resource_ref: "passkey-target-2"))
    assert_refused_and_kept(token, requirement(token, resource_ref: nil))
  end

  test "a requirement naming another actor is refused and the evidence is kept" do
    token = evidence_token(ClientToken.find(ActiveRecord::FixtureSet.identify(:one)))

    assert_refused_and_kept(
      token,
      requirement(token, actor_ref: "another-principal"),
      error: TokenStatusManagement::StepUpEvidenceUnavailable,
    )
  end

  test "evidence recorded for another session is refused and kept" do
    token = evidence_token(ClientToken.find(ActiveRecord::FixtureSet.identify(:one)))
    other_session = ClientToken.find(ActiveRecord::FixtureSet.identify(:two))

    assert_refused_and_kept(token, requirement(token, session_binding: other_session.public_id))
    token.update!(last_step_up_session_public_id: other_session.public_id)

    assert_refused_and_kept(token, requirement(token))
  end

  test "NORMAL evidence cannot authorize Step-Up while Governance policy is unavailable at time boundaries" do
    token = ClientToken.find(ActiveRecord::FixtureSet.identify(:one))

    [15.minutes - 1.second, 15.minutes, 15.minutes + 1.second].each do |age|
      assert_refused_and_kept(evidence_token(token, age: age), requirement(token))
    end
  end

  test "ADVANCED evidence cannot authorize Step-Up while Governance policy is unavailable at time boundaries" do
    token = OperatorToken.find(ActiveRecord::FixtureSet.identify(:one))

    [5.minutes - 1.second, 5.minutes, 5.minutes + 1.second].each do |age|
      assert_refused_and_kept(evidence_token(token, age: age, method: "passkey"), requirement(token))
    end
  end

  test "an unavailable Governance policy keeps evidence for a later retry" do
    token = evidence_token(ClientToken.find(ActiveRecord::FixtureSet.identify(:one)))

    assert_raises(GovernanceLookupUnavailableError) do
      ClientToken.transaction do
        token.consume_step_up_evidence!(requirement: requirement(token), now: NOW)
      end
    end

    assert_equal IdentityStepUpCeremonyContract::EVIDENCE_RECORDED, token.reload.evidence_state_id
    assert_equal SCOPE, token.last_step_up_scope
    assert_instance_of TrueClass, token.last_step_up_user_verified
  end

  test "a requirement that does not demand Step-Up cannot consume evidence" do
    token = evidence_token(ClientToken.find(ActiveRecord::FixtureSet.identify(:one)))
    not_required = StepUpRequirement.new(step_up_required: false)

    assert_raises(ArgumentError) { token.consume_step_up_evidence!(requirement: not_required, now: NOW) }
  end

  private

  def evidence_token(token, method: "email_otp", age: 1.second)
    token.update!(
      evidence_state_id: IdentityStepUpCeremonyContract::EVIDENCE_RECORDED,
      last_step_up_at: NOW - age, last_step_up_scope: SCOPE, last_step_up_method: method,
      last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
      last_step_up_audience: "step_up:test", last_step_up_credential_ref: SecureRandom.uuid,
      last_step_up_phishing_resistant: false, last_step_up_user_verified: true,
      last_step_up_full_reauthentication: false, last_step_up_resource_ref: TARGET,
    )
    token
  end

  def requirement(token, scope: SCOPE, audience: "step_up:test", resource_ref: TARGET,
                  actor_ref: token.device_session.subject_public_id, session_binding: token.public_id)
    StepUpRequirement.new(
      step_up_required: true, scope: scope, allowed_methods: %i(email_otp passkey totp),
      phishing_resistant_required: false, user_verification_required: false,
      full_reauthentication_required: false, session_binding: session_binding, token_binding: token.public_id,
      ttl: 15.minutes, purpose: "step_up", audience: audience, require_session_binding: true,
      actor_ref: actor_ref, resource_ref: resource_ref, tenant_ref: nil,
    )
  end

  def assert_refused_and_kept(token, refused_requirement, error: GovernanceLookupUnavailableError)
    evidence_before = token.attributes.slice(
      "evidence_state_id", "last_step_up_at", "last_step_up_scope", "last_step_up_method",
      "last_step_up_session_public_id", "last_step_up_purpose", "last_step_up_audience",
      "last_step_up_credential_ref", "last_step_up_phishing_resistant", "last_step_up_user_verified",
      "last_step_up_full_reauthentication", "last_step_up_resource_ref", "last_step_up_tenant_ref",
    )
    assert_raises(error) do
      token.consume_step_up_evidence!(requirement: refused_requirement, now: NOW)
    end

    assert_equal evidence_before, token.reload.attributes.slice(*evidence_before.keys)
  end
end
