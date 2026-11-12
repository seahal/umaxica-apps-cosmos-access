# frozen_string_literal: true

require "test_helper"

class OpCeremonyCheckBoundariesTest < ActiveSupport::TestCase
  test "email ceremony attempt counts enforce zero at the database boundary on both surfaces" do
    [ClientEmailCeremonyTransaction, OperatorEmailCeremonyTransaction].each do |model|
      issued = model.issue_evp_challenge!(
        actor_ref: "actor", session_ref: "session", operation: "registration",
        email_candidate_ref: "candidate", normalized_email_digest: "digest",
      )
      relation = model.where(id: issued.transaction.id)

      [0, 1].each do |attempt_count|
        assert_equal 1, relation.update_all(evp_attempt_count: attempt_count)
        assert_equal attempt_count, issued.transaction.reload.evp_attempt_count
      end
      error =
        assert_raises(ActiveRecord::StatementInvalid) do
          model.transaction(requires_new: true) { relation.update_all(evp_attempt_count: -1) }
        end

      assert_instance_of PG::CheckViolation, error.cause
      assert_equal 1, issued.transaction.reload.evp_attempt_count
    end
  end

  test "step up retention ordering enforces the nearest database instants on both surfaces" do
    [
      [ClientStepUpSession, { user_token: client_tokens(:one) }],
      [OperatorStepUpSession, { staff_token: operator_tokens(:one) }],
    ].each do |model, parent|
      deadline = model.database_now + 1.day
      session = model.create!(
        **parent, scope: "account_update", return_to: "/account", status: "PENDING",
                  discard_at: deadline, purge_eligible_at: deadline,
      )
      relation = model.where(id: session.id)

      [deadline - Rational(1, 1_000_000), deadline].each do |discard_at|
        assert_equal 1, relation.update_all(discard_at: discard_at, purge_eligible_at: deadline)
        assert_equal discard_at, session.reload.discard_at
      end
      error =
        assert_raises(ActiveRecord::StatementInvalid) do
          model.transaction(requires_new: true) { relation.update_all(discard_at: deadline + Rational(1, 1_000_000)) }
        end

      assert_instance_of PG::CheckViolation, error.cause
      assert_equal deadline, session.reload.discard_at
    end
  end
end
