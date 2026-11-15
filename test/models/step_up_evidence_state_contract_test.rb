# frozen_string_literal: true

require "test_helper"

class StepUpEvidenceStateContractTest < ActiveSupport::TestCase
  self.fixture_table_names = %w(client_tokens operator_tokens client_device_sessions operator_device_sessions)

  test "PostgreSQL enforces token boolean state and reference invariants through bulk updates" do
    [
      [ClientToken, ClientStepUpEvidenceState, :subject_public_id],
      [OperatorToken, OperatorStepUpEvidenceState, :subject_public_id],
    ].each do |model, catalog, owner_key|
      historical = model.find(ActiveRecord::FixtureSet.identify(:one))
      token = model.create!(
        :device_session_id => historical.device_session_id,
        owner_key => historical[owner_key],
        :authentication_epoch => 0,
      )
      relation = model.where(id: token.id)

      %i(evidence_state_id last_step_up_user_verified last_step_up_full_reauthentication).each do |attribute|
        assert_raises(ActiveRecord::NotNullViolation) do
          model.transaction(requires_new: true) { relation.update_all(attribute => nil) }
        end
      end
      assert_raises(ActiveRecord::InvalidForeignKey) do
        model.transaction(requires_new: true) { relation.update_all(evidence_state_id: 0) }
      end
      %i(last_step_up_user_verified last_step_up_full_reauthentication).each do |attribute|
        error =
          assert_raises(ActiveRecord::StatementInvalid) do
            model.transaction(requires_new: true) { relation.update_all(attribute => true) }
          end
        assert_instance_of PG::CheckViolation, error.cause
      end
      assert_raises(ActiveRecord::DeleteRestrictionError) { catalog.find(10).destroy! }
      error =
        assert_raises(ActiveRecord::StatementInvalid) do
          catalog.transaction(requires_new: true) { catalog.where(id: 10).delete_all }
        end
      assert_instance_of PG::RestrictViolation, error.cause
      assert_equal 10, token.reload.evidence_state_id
      assert_same false, token.last_step_up_user_verified
      assert_same false, token.last_step_up_full_reauthentication
    end
  end

  test "evidence associations reject a catalog record from the other realm" do
    app_state = ClientStepUpEvidenceState.find(10)
    org_state = OperatorStepUpEvidenceState.find(10)
    assert_raises(ActiveRecord::AssociationTypeMismatch) { ClientToken.new(evidence_state: org_state) }
    assert_raises(ActiveRecord::AssociationTypeMismatch) { OperatorToken.new(evidence_state: app_state) }
    assert_raises(ActiveRecord::AssociationTypeMismatch) { ClientStepUpCeremonyTransaction.new(evidence_state: org_state) }
    assert_raises(ActiveRecord::AssociationTypeMismatch) { OperatorStepUpCeremonyTransaction.new(evidence_state: app_state) }
  end

  test "registration records negative properties without asserting step up authority" do
    [ClientStepUpCeremonyTransaction, OperatorStepUpCeremonyTransaction].each do |model|
      transaction = model.create_transaction!(
        actor_ref: "actor", session_ref: "session", required_scope: "settings_passkey",
        required_aal: "none", allowed_methods: ["passkey"], purpose: "credential_registration", step_up_required: false,
      )
      transaction.record_registration_verification!(method: "passkey", verified_at: model.database_now)

      assert_equal IdentityStepUpCeremonyContract::EVIDENCE_RECORDED, transaction.reload.evidence_state_id
      assert_same false, transaction.user_verified
      assert_not transaction.step_up_required

      transaction.with_lock do
        transaction.commit_registration_consumption!(
          now: model.database_now, method: "passkey", registered_credential_ref: "registered-credential",
        )
      end

      assert_equal "consumed", transaction.reload.status
      assert_equal IdentityStepUpCeremonyContract::EVIDENCE_RECORDED, transaction.evidence_state_id
      assert_same false, transaction.user_verified
    end
  end

  test "absent and recorded negative ceremony evidence remain distinct through every terminal edge" do
    [ClientStepUpCeremonyTransaction, OperatorStepUpCeremonyTransaction].each do |model|
      [false, true].each do |recorded|
        %i(canceled expired revoked).each do |terminal|
          transaction = model.create_transaction!(
            actor_ref: "actor", session_ref: "session", required_scope: "settings_passkey",
            required_aal: "none", allowed_methods: ["passkey"], purpose: "step_up",
          )

          assert_equal "pending", transaction.reload.status
          assert_equal IdentityStepUpCeremonyContract::EVIDENCE_ABSENT, transaction.evidence_state_id
          assert_same false, transaction.user_verified

          if recorded
            transaction.record_verification!(
              method: "passkey", aal: "aal1", phishing_resistant: true, user_verified: false,
              verified_at: model.database_now, verified_credential_ref: "credential",
            )

            assert_equal "verified", transaction.reload.status
            assert_equal IdentityStepUpCeremonyContract::EVIDENCE_RECORDED, transaction.evidence_state_id
            assert_same false, transaction.user_verified
          end

          transaction.with_lock do
            case terminal
            when :canceled then transaction.commit_cancellation!(now: model.database_now)
            when :expired then transaction.commit_expiry!
            when :revoked then transaction.commit_revocation!(now: model.database_now)
            else raise ArgumentError, "unsupported terminal test case"
            end
          end
          expected_state =
            recorded ? IdentityStepUpCeremonyContract::EVIDENCE_RECORDED :
                       IdentityStepUpCeremonyContract::EVIDENCE_ABSENT

          assert_equal terminal.to_s, transaction.reload.status
          assert_equal expected_state, transaction.evidence_state_id
          assert_same false, transaction.user_verified
        end
      end
    end
  end

  test "token evidence revocation clears its explicit state while retaining root authority" do
    [
      [ClientToken, :subject_public_id],
      [OperatorToken, :subject_public_id],
    ].each do |model, owner_key|
      historical = model.find(ActiveRecord::FixtureSet.identify(:one))
      token = model.create!(
        :device_session_id => historical.device_session_id, owner_key => historical[owner_key],
        :authentication_epoch => 0, :discard_at => 1.day.from_now,
      )
      token.update!(
        evidence_state_id: IdentityStepUpCeremonyContract::EVIDENCE_RECORDED,
        last_step_up_user_verified: true, last_step_up_full_reauthentication: false,
      )
      original_status = token.attributes.slice("user_token_status_id", "staff_token_status_id")
      original_deadline = token.reload.discard_at

      token.revoke_step_up_authority!

      assert_equal IdentityStepUpCeremonyContract::EVIDENCE_ABSENT, token.reload.evidence_state_id
      assert_same false, token.last_step_up_user_verified
      assert_same false, token.last_step_up_full_reauthentication
      assert_equal original_status, token.attributes.slice("user_token_status_id", "staff_token_status_id")
      assert_equal original_deadline, token.discard_at
      assert_predicate token, :persisted?
    end
  end

  test "PostgreSQL rejects missing flags states and contradictory absent ceremony evidence" do
    [ClientStepUpCeremonyTransaction, OperatorStepUpCeremonyTransaction].each do |model|
      transaction = model.create_transaction!(
        actor_ref: "actor", session_ref: "session", required_scope: "settings_passkey",
        required_aal: "none", allowed_methods: ["passkey"], purpose: "step_up",
      )

      %i(user_verified evidence_state_id).each do |attribute|
        assert_raises(ActiveRecord::NotNullViolation) do
          model.transaction(requires_new: true) { model.where(id: transaction.id).update_all(attribute => nil) }
        end
      end
      error =
        assert_raises(ActiveRecord::StatementInvalid) do
          model.transaction(requires_new: true) { model.where(id: transaction.id).update_all(user_verified: true) }
        end
      assert_instance_of PG::CheckViolation, error.cause

      transaction.with_lock { transaction.commit_revocation!(now: model.database_now) }
      assert_raises(ActiveRecord::InvalidForeignKey) do
        model.transaction(requires_new: true) { model.where(id: transaction.id).update_all(evidence_state_id: 0) }
      end
      assert_equal IdentityStepUpCeremonyContract::EVIDENCE_ABSENT, transaction.reload.evidence_state_id
      assert_same false, transaction.user_verified
    end
  end
end
