# typed: false
# frozen_string_literal: true

require "test_helper"
require "concurrent/executor/simple_executor_service"

class SessionLimitResolutionTransactionableTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "actor-dependent model selection is unavailable without Governance" do
    assert_raises(GovernanceLookupUnavailableError) { SessionLimitResolutionTransactionable.model_for(nil) }
  end

  test "resolution class mappings reject an unregistered model subclass" do
    unsupported_model = Class.new(ClientSessionLimitResolutionTransaction)

    assert_raises(GovernanceLookupUnavailableError) { unsupported_model.resolution_actor_class }
    assert_raises(FlowConfigurationError) { unsupported_model.resolution_token_class }
    assert_raises(FlowConfigurationError) { unsupported_model.resolution_device_session_class }
    assert_raises(FlowConfigurationError) { unsupported_model.resolution_sign_in_flow_class }
    assert_raises(FlowConfigurationError) { unsupported_model.resolution_oidc_authorization_transaction_class }
    assert_raises(FlowConfigurationError) { unsupported_model.resolution_state_class }
  end

  test "retained query APIs find the matching open transaction by challenge" do
    now = ClientSignInFlow.database_now
    flow = ClientSignInFlow.create!(
      nonce_digest: ClientSignInFlow.digest_nonce(SecureRandom.urlsafe_base64(32)),
      issued_at: now,
      expires_at: now + 5.minutes,
    )
    challenge = SecureRandom.urlsafe_base64(32)
    transaction = ClientSessionLimitResolutionTransaction.create!(
      challenge_digest: ClientSessionLimitResolutionTransaction.digest_challenge(challenge),
      state_id: SessionLimitResolutionTransactionable::PENDING,
      waiting_slot: SessionLimitResolutionTransactionable::WAITING_SLOT,
      sign_in_flow_id: flow.id,
      actor_ref: "historical-resolution-subject",
      browser_binding_digest: "f" * 64,
      started_at: now,
      expires_at: now + 5.minutes,
    )

    assert_includes ClientSessionLimitResolutionTransaction.open, transaction
    assert_includes ClientSessionLimitResolutionTransaction.active_at, transaction
    # Public method lookup avoids Rails/DynamicFindBy mistaking this explicit domain query for a dynamic finder.
    assert_equal transaction,
                 ClientSessionLimitResolutionTransaction.public_method(:find_by_challenge).call(challenge)
    assert_equal transaction, ClientSessionLimitResolutionTransaction.find_active_by_challenge(challenge)
  end

  test "elapsed actor resolution remains unavailable without Governance" do
    assert_raises(GovernanceLookupUnavailableError) do
      ClientSessionLimitResolutionTransaction.expire_elapsed_for_actor!(nil, writer_now: Time.current)
    end
  end
end

class SessionLimitResolutionDatabaseHistoryTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  [
    [ClientSignInFlow, ClientSessionLimitResolutionTransaction],
    [OperatorSignInFlow, OperatorSessionLimitResolutionTransaction],
  ].each do |flow_class, resolution_class|
    test "#{resolution_class.name} open status stops exactly at its deadline" do
      deadline = Time.utc(2026, 1, 1)
      row = resolution_class.new(
        state_id: SessionLimitResolutionTransactionable::PENDING, waiting_slot: 1,
        expires_at: deadline,
      )
      [-1, 0, 1].each do |microseconds|
        resolution_class.stub(:database_now, deadline + Rational(microseconds, 1_000_000)) do
          assert_equal microseconds.negative?, row.open?
        end
      end
    end

    test "#{resolution_class.name} terminal and elapsed predicates read persisted state precisely" do
      deadline = Time.utc(2026, 1, 1)
      row = resolution_class.new(
        state_id: SessionLimitResolutionTransactionable::CANCELLED,
        expires_at: deadline,
      )

      assert_predicate row, :terminal?
      assert_not row.pending?
      [-1, 0, 1].each do |microseconds|
        resolution_class.stub(:database_now, deadline + Rational(microseconds, 1_000_000)) do
          assert_equal !microseconds.negative?, row.expired_at?
        end
      end
    end

    test "#{resolution_class.name} PostgreSQL preserves waiting-slot state in retained history" do
      now = flow_class.database_now
      flow = flow_class.create!(
        nonce_digest: flow_class.digest_nonce(SecureRandom.urlsafe_base64(32)),
        issued_at: now, expires_at: now + 5.minutes,
      )
      row = resolution_class.create!(
        challenge_digest: resolution_class.digest_challenge(SecureRandom.urlsafe_base64(32)),
        state_id: SessionLimitResolutionTransactionable::PENDING,
        waiting_slot: SessionLimitResolutionTransactionable::WAITING_SLOT,
        sign_in_flow_id: flow.id,
        actor_ref: "historical-subject",
        browser_binding_digest: "e" * 64,
        started_at: now,
        expires_at: now + 5.minutes,
      )

      error =
        assert_raises(ActiveRecord::StatementInvalid) do
          resolution_class.transaction(requires_new: true) { row.update_columns(waiting_slot: nil) }
        end

      assert_instance_of PG::CheckViolation, error.cause
      assert_equal SessionLimitResolutionTransactionable::WAITING_SLOT, row.reload.waiting_slot
      row.update_columns(
        state_id: SessionLimitResolutionTransactionable::CANCELLED, waiting_slot: nil,
        cancelled_at: now,
      )

      assert_nil row.reload.waiting_slot
      error =
        assert_raises(ActiveRecord::StatementInvalid) do
          resolution_class.transaction(requires_new: true) do
            row.update_columns(waiting_slot: SessionLimitResolutionTransactionable::WAITING_SLOT)
          end
        end

      assert_instance_of PG::CheckViolation, error.cause
      assert_nil row.reload.waiting_slot
      assert_predicate row, :cancelled?
    end
  end
end

class SessionLimitResolutionDatabaseConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  [
    [ClientSignInFlow, ClientSessionLimitResolutionTransaction],
    [OperatorSignInFlow, OperatorSessionLimitResolutionTransaction],
  ].each do |flow_class, resolution_class|
    test "#{resolution_class.name} concurrent waiting-slot inserts admit one claimant" do
      now = flow_class.database_now
      actor_ref = "historical-#{SecureRandom.uuid}"
      flows =
        2.times.map do
          flow_class.create!(
            nonce_digest: flow_class.digest_nonce(SecureRandom.urlsafe_base64(32)),
            issued_at: now, expires_at: now + 5.minutes,
          )
        end
      ready = Queue.new
      release = Queue.new
      workers =
        flows.map do |flow|
          Concurrent::Future.execute(executor: Concurrent::SimpleExecutorService.new) do
            resolution_class.connection_pool.with_connection do
              ready << true
              release.pop
              resolution_class.insert_all!(
                [{
                  challenge_digest: resolution_class.digest_challenge(SecureRandom.urlsafe_base64(32)),
                  state_id: SessionLimitResolutionTransactionable::PENDING,
                  waiting_slot: SessionLimitResolutionTransactionable::WAITING_SLOT,
                  sign_in_flow_id: flow.id,
                  actor_ref: actor_ref,
                  browser_binding_digest: "a" * 64,
                  started_at: now,
                  expires_at: now + 5.minutes,
                }],
              )
              :created
            rescue ActiveRecord::RecordNotUnique
              :conflict
            end
          ensure
            ActiveRecord::Base.connection_handler.clear_active_connections!
          end
        end
      2.times { ready.pop }
      2.times { release << true }
      outcomes = workers.map(&:value!)

      assert_equal %i(conflict created), outcomes.sort
      assert_equal 1, resolution_class.where(actor_ref: actor_ref, waiting_slot: 1).count
      assert_equal 1, resolution_class.where(sign_in_flow_id: flows.map(&:id)).count
    ensure
      2.times { release << true } if release
      workers&.each(&:wait)
      resolution_class.where(actor_ref: actor_ref).delete_all if actor_ref
      flow_class.where(id: flows.map(&:id)).delete_all if flows
    end
  end
end
