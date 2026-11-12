# frozen_string_literal: true

require "test_helper"

class SessionLimitResolutionUniquenessTest < ActiveSupport::TestCase
  test "resolution model selection refuses without Governance" do
    assert_raises(GovernanceLookupUnavailableError) { SessionLimitResolutionTransactionable.model_for(nil) }
  end

  [
    [ClientSignInFlow, ClientSessionLimitResolutionTransaction],
    [OperatorSignInFlow, OperatorSessionLimitResolutionTransaction],
  ].each do |flow_class, resolution_class|
    test "#{resolution_class.name} retains partial uniqueness and terminal history in PostgreSQL" do
      now = flow_class.database_now
      flows =
        2.times.map do
          flow_class.create!(
            nonce_digest: flow_class.digest_nonce(SecureRandom.urlsafe_base64(32)),
            issued_at: now, expires_at: now + 300,
          )
        end
      # Historical OP rows contain only opaque references; no Governance actor is fabricated.
      attributes = {
        challenge_digest: resolution_class.digest_challenge("first"),
        state_id: SessionLimitResolutionTransactionable::PENDING,
        waiting_slot: SessionLimitResolutionTransactionable::WAITING_SLOT,
        sign_in_flow_id: flows.first.id,
        actor_ref: "historical-subject",
        browser_binding_digest: "a" * 64,
        started_at: now,
        expires_at: now + 300,
      }
      first = resolution_class.create!(attributes)
      duplicate = resolution_class.new(
        attributes.merge(challenge_digest: resolution_class.digest_challenge("duplicate")),
      )

      assert_not duplicate.valid?
      assert duplicate.errors.of_kind?(:sign_in_flow_id, :taken)
      assert duplicate.errors.of_kind?(:actor_ref, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }

      same_parent = resolution_class.new(
        attributes.merge(
          actor_ref: "another-historical-subject",
          challenge_digest: resolution_class.digest_challenge("parent"),
        ),
      )

      assert_not same_parent.valid?
      assert same_parent.errors.of_kind?(:sign_in_flow_id, :taken)
      assert_not same_parent.errors.of_kind?(:actor_ref, :taken)
      assert_raises(ActiveRecord::RecordNotUnique) do
        resolution_class.transaction(requires_new: true) { same_parent.save!(validate: false) }
      end

      same_actor = resolution_class.new(
        attributes.merge(sign_in_flow_id: flows.last.id, challenge_digest: resolution_class.digest_challenge("actor")),
      )

      assert_not same_actor.valid?
      assert_not same_actor.errors.of_kind?(:sign_in_flow_id, :taken)
      assert same_actor.errors.of_kind?(:actor_ref, :taken)
      assert_raises(ActiveRecord::RecordNotUnique) do
        resolution_class.transaction(requires_new: true) { same_actor.save!(validate: false) }
      end

      elapsed = resolution_class.new(
        attributes.merge(expires_at: now - 1, challenge_digest: resolution_class.digest_challenge("elapsed")),
      )

      assert_not elapsed.valid?
      assert elapsed.errors.of_kind?(:sign_in_flow_id, :taken)
      assert elapsed.errors.of_kind?(:actor_ref, :taken)
      closed = resolution_class.create!(
        attributes.merge(
          challenge_digest: resolution_class.digest_challenge("closed"),
          state_id: SessionLimitResolutionTransactionable::CANCELLED,
          waiting_slot: nil, cancelled_at: now,
        ),
      )

      assert_predicate closed, :cancelled?
      assert_predicate first.reload, :pending?
      assert_equal 2, resolution_class.where(sign_in_flow_id: flows.first.id).count
    end

    {
      "select_session!" => ->(row, _flow) {
        row.select_session!(
          actor: nil, challenge: "challenge", session_ref: "session",
          browser_binding_digest: "a" * 64,
        )
      },
      "resolve!" => ->(row, _flow) {
        row.resolve!(actor: nil, challenge: "challenge", browser_binding_digest: "a" * 64)
      },
      "cancel!" => ->(row, _flow) { row.cancel!(actor: nil, challenge: "challenge", browser_binding_digest: "a" * 64) },
      "expire!" => ->(row, _flow) { row.expire! },
      "finalize_for_session_issuance!" => ->(row, flow) {
        row.finalize_for_session_issuance!(
          actor: nil, parent: flow, challenge: "challenge", browser_binding_digest: "a" * 64,
        ) { :within_limit }
      },
    }.each do |operation, perform|
      test "#{resolution_class.name} #{operation} refuses without changing retained history" do
        now = flow_class.database_now
        flow = flow_class.create!(
          nonce_digest: flow_class.digest_nonce(SecureRandom.urlsafe_base64(32)),
          issued_at: now, expires_at: now + 300,
        )
        row = resolution_class.create!(
          challenge_digest: resolution_class.digest_challenge("challenge"),
          state_id: SessionLimitResolutionTransactionable::PENDING,
          waiting_slot: SessionLimitResolutionTransactionable::WAITING_SLOT,
          sign_in_flow_id: flow.id,
          actor_ref: "historical-subject",
          browser_binding_digest: "a" * 64,
          started_at: now,
          expires_at: now + 300,
        )
        original = row.reload.attributes

        assert_raises(GovernanceLookupUnavailableError) { perform.call(row, flow) }
        assert_equal original, row.reload.attributes
      end
    end

    test "#{resolution_class.name} refuses issuance without Governance" do
      now = flow_class.database_now
      flow = flow_class.create!(
        nonce_digest: flow_class.digest_nonce(SecureRandom.urlsafe_base64(32)),
        issued_at: now, expires_at: now + 300,
      )

      assert_no_difference -> { resolution_class.count } do
        assert_raises(GovernanceLookupUnavailableError) do
          resolution_class.issue!(sign_in_flow: flow, actor: nil, browser_binding_digest: "a" * 64)
        end
      end
    end

    test "#{flow_class.name} rejects authentication evidence without Governance" do
      now = flow_class.database_now
      flow = flow_class.create!(
        nonce_digest: flow_class.digest_nonce(SecureRandom.urlsafe_base64(32)),
        issued_at: now, expires_at: now + 300,
      )

      assert_raises(GovernanceLookupUnavailableError) { flow.record_authentication_evidence!(method: "passkey") }
      assert_nil flow.reload.authentication_event_at
      assert_nil flow.authentication_method
    end
  end
end
