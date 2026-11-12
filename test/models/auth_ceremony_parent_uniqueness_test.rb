# frozen_string_literal: true

require "test_helper"
require "concurrent/executor/simple_executor_service"
require "timeout"

class AuthCeremonyParentUniquenessTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  [ClientAuthCeremonySession, OperatorAuthCeremonySession].each do |model|
    test "#{model.name} validates a claimed parent and PostgreSQL enforces the same contract" do
      first, = model.issue!
      second, = model.issue!
      ref = SecureRandom.uuid
      first.admit!(admission_purpose: "authentication_handoff", authorization_transaction_ref: ref)
      second.assign_attributes(
        status_id: AuthCeremonySession::STATUS_ADMITTED,
        admission_purpose: "authentication_handoff", admitted_at: model.database_now,
        authorization_transaction_ref: ref,
      )

      assert_not second.valid?
      assert second.errors.of_kind?(:authorization_transaction_ref, :taken)
      assert_raises(ActiveRecord::RecordInvalid) { second.save! }
      assert_raises(ActiveRecord::RecordNotUnique) do
        model.transaction(requires_new: true) do
          model.where(id: second.id).update_all(
            status_id: AuthCeremonySession::STATUS_ADMITTED,
            admission_purpose: "authentication_handoff",
            admitted_at: model.database_now,
            authorization_transaction_ref: ref,
          )
        end
      end
      assert_equal AuthCeremonySession::STATUS_ISSUED, second.reload.status_id
      assert_equal ref, first.reload.authorization_transaction_ref
    end

    [false, true].each do |progress|
      test "#{model.name} releases the parent after cancellation with progress=#{progress}" do
        first, = model.issue!
        second, = model.issue!
        ref = SecureRandom.uuid
        first.admit!(admission_purpose: "authentication_handoff", authorization_transaction_ref: ref)
        first.record_authentication_evidence!(method: "passkey") if progress
        first.cancel!
        second.admit!(admission_purpose: "authentication_handoff", authorization_transaction_ref: ref)

        assert_equal(
          progress ? AuthCeremonySession::STATUS_CANCELLED_AFTER_PROGRESS :
                    AuthCeremonySession::STATUS_CANCELLED_BEFORE_PROGRESS, first.reload.status_id,
        )
        assert_equal ref, second.reload.authorization_transaction_ref
      end
    end
  end
end

class AuthCeremonyParentUniquenessConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  [ClientAuthCeremonySession, OperatorAuthCeremonySession].each do |model|
    test "#{model.name} simultaneous SQL claims have one winner" do
      sessions = 2.times.map { model.issue!.first }
      ready = Queue.new
      release = Queue.new
      ref = SecureRandom.uuid
      workers =
        sessions.map do |session|
          Concurrent::Future.execute(executor: Concurrent::SimpleExecutorService.new) do
            model.connection_pool.with_connection do |connection|
              ready << connection.select_value("SELECT pg_backend_pid()")
              release.pop
              model.where(id: session.id).update_all(
                status_id: AuthCeremonySession::STATUS_ADMITTED,
                admission_purpose: "authentication_handoff",
                admitted_at: model.database_now,
                authorization_transaction_ref: ref,
              )
              :created
            rescue ActiveRecord::RecordNotUnique
              :conflict
            end
          ensure
            ActiveRecord::Base.connection_handler.clear_active_connections!
          end
        end
      backends = Timeout.timeout(10) { 2.times.map { ready.pop } }
      2.times { release << true }
      outcomes = Timeout.timeout(10) { workers.map(&:value!) }

      assert_equal 2, backends.uniq.size
      assert_equal %i(conflict created), outcomes.sort
      assert_equal 1, model.where(authorization_transaction_ref: ref).count
    ensure
      2.times { release << true } if release
      workers&.each { |worker| worker.wait(10) }
      model.where(id: sessions.map(&:id)).delete_all if sessions
    end
  end
end
