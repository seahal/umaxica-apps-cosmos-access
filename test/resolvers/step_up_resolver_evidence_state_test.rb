# frozen_string_literal: true

require "test_helper"

class StepUpResolverEvidenceStateTest < ActiveSupport::TestCase
  test "absent token evidence rejects either positive property without silently recording proof" do
    [
      [ClientToken, { user: clients(:one) }],
      [OperatorToken, { staff: operators(:one) }],
    ].each do |model, parent|
      token = model.create!(**parent, authentication_epoch: 0)
      [[true, false], [false, true], [true, true]].each do |user_verified, full_reauthentication|
        token.assign_attributes(
          evidence_state_id: IdentityStepUpCeremonyContract::EVIDENCE_ABSENT,
          last_step_up_user_verified: user_verified,
          last_step_up_full_reauthentication: full_reauthentication,
        )

        assert_not_predicate token, :valid?
        assert token.errors.of_kind?(:evidence_state_id, :invalid)
        assert_equal IdentityStepUpCeremonyContract::EVIDENCE_ABSENT, token.evidence_state_id
      end
    end
  end

  test "an absent evidence state refuses a complete-looking token proof on both surfaces" do
    [
      [ClientToken, { user: clients(:one) }],
      [OperatorToken, { staff: operators(:one) }],
    ].each do |model, parent|
      now = model.database_now
      token = model.create!(**parent, authentication_epoch: 0, root_login_established_at: now)
      token.assign_attributes(
        evidence_state_id: IdentityStepUpCeremonyContract::EVIDENCE_ABSENT,
        last_step_up_at: now, last_step_up_scope: "settings_email", last_step_up_method: "passkey",
        last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
        last_step_up_audience: "step_up:resolver", last_step_up_credential_ref: "credential",
        last_step_up_phishing_resistant: false, last_step_up_user_verified: false,
        last_step_up_full_reauthentication: false,
      )
      result = StepUpResolver.call(token: token, scope: "settings_email", now: now)

      assert result.usable_token
      assert_not result.satisfied
    end
  end

  test "recorded false evidence is usable only when neither true property is required on both surfaces" do
    [
      [ClientToken, { user: clients(:one) }],
      [OperatorToken, { staff: operators(:one) }],
    ].each do |model, parent|
      now = model.database_now
      token = model.create!(**parent, authentication_epoch: 0, root_login_established_at: now)
      token.assign_attributes(
        evidence_state_id: IdentityStepUpCeremonyContract::EVIDENCE_RECORDED,
        last_step_up_at: now, last_step_up_scope: "settings_email", last_step_up_method: "passkey",
        last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
        last_step_up_audience: "step_up:resolver", last_step_up_credential_ref: "credential",
        last_step_up_phishing_resistant: false, last_step_up_user_verified: false,
        last_step_up_full_reauthentication: false,
      )

      assert StepUpResolver.call(token: token, scope: "settings_email", now: now).satisfied
      assert_not StepUpResolver.call(
        token: token, scope: "settings_email", now: now, user_verification_required: true,
      ).satisfied

      token.last_step_up_purpose = "reauthentication"

      assert_not StepUpResolver.call(
        token: token, scope: "settings_email", now: now, purpose: "reauthentication",
        full_reauthentication_required: true,
      ).satisfied

      token.assign_attributes(last_step_up_user_verified: true, last_step_up_full_reauthentication: true)

      assert StepUpResolver.call(
        token: token, scope: "settings_email", now: now,
        user_verification_required: true, full_reauthentication_required: true, purpose: "reauthentication",
      ).satisfied
    end
  end

  test "missing and unknown evidence states fail closed even when every proof property is true" do
    [
      [ClientToken, { user: clients(:one) }],
      [OperatorToken, { staff: operators(:one) }],
    ].each do |model, parent|
      token = model.create!(**parent, authentication_epoch: 0)
      now = model.database_now
      token.assign_attributes(
        last_step_up_at: now, last_step_up_scope: "settings_email", last_step_up_method: "passkey",
        last_step_up_session_public_id: token.public_id, last_step_up_purpose: "step_up",
        last_step_up_audience: "step_up:resolver", last_step_up_credential_ref: "credential",
        last_step_up_phishing_resistant: true, last_step_up_user_verified: true,
        last_step_up_full_reauthentication: true,
      )
      [nil, 0, 999].each do |evidence_state|
        token.evidence_state_id = evidence_state

        assert_not StepUpResolver.call(token: token, scope: "settings_email", now: now).satisfied
      end
    end
  end
end
