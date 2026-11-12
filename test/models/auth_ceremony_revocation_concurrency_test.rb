# frozen_string_literal: true

require "test_helper"
require "timeout"

# A committed row and separate writer connections expose the one-shot revocation boundary.
class AuthCeremonyRevocationConcurrencyTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  self.use_transactional_tests = false
  [
    [ClientStepUpCeremonyTransaction, ClientAuthCeremonySession, OpBaseAppRecord, :app],
    [OperatorStepUpCeremonyTransaction, OperatorAuthCeremonySession, OpBaseOrgRecord, :org],
  ].each do |parent_model, continuity_model, writer_model, surface|
    test "#{surface} writer connections close expired continuity once and refuse its competing transition" do
      parent = parent_model.create_transaction!(
        actor_ref: "concurrency-actor", session_ref: "concurrency-session", required_scope: "settings_passkey",
        required_aal: "none", allowed_methods: ["passkey"],
      )
      continuity, = continuity_model.rotate_and_admit!(
        admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: parent.transaction_id, ttl: 1.second,
      )
      decision_time = continuity.expires_at
      ready = Queue.new
      release = Queue.new
      ActiveRecord::Base.connection_handler.clear_active_connections!
      threads =
        Array.new(2) do
          Thread.new do
            writer_model.connected_to(role: :writing) do
              writer_model.connection_pool.with_connection do |connection|
                ready << connection.select_value("SELECT pg_backend_pid()")
                release.pop
                begin
                  continuity_model.find(continuity.id).revoke!
                  :revoked
                rescue AuthCeremonySession::InvalidTransition
                  :terminal_refused
                end
              end
            end
          end
        end
      pids = nil
      results =
        continuity_model.stub(:database_now, decision_time) do
          Timeout.timeout(10) do
            pids = [ready.pop, ready.pop]
            2.times { release << true }
            threads.map(&:value)
          end
        end

      assert_equal 2, pids.uniq.length
      assert_equal [:revoked, :terminal_refused], results.sort
      assert_equal decision_time.iso8601(6), continuity.reload.revoked_at.iso8601(6)
      assert_predicate continuity, :terminal?
      assert_not continuity.active?(now: decision_time)
      assert_raises(AuthCeremonySession::InvalidTransition) do
        continuity.record_authentication_evidence!(method: "passkey")
      end
    ensure
      if threads
        2.times { release << true }
        threads.each do |thread|
          thread.kill unless thread.join(10)
        end
      end
      if parent
        continuity_model.where(step_up_ceremony_transaction_ref: parent.transaction_id).delete_all
        parent_model.where(id: parent.id).delete_all
      end
    end
  end

  test "APP cleanup racing expired continuity revocation either retains the complete cohort or removes it atomically" do
    now = Time.current
    parent = ClientStepUpCeremonyTransaction.create_transaction!(
      actor_ref: "cleanup-race-actor", session_ref: "cleanup-race-session", required_scope: "settings_passkey",
      required_aal: "none", allowed_methods: ["passkey"], now: now - 9.days, expires_at: now - 8.days,
    )
    continuity, = ClientAuthCeremonySession.rotate_and_admit!(
      admission_purpose: "step_up_handoff", step_up_ceremony_transaction_ref: parent.transaction_id,
    )
    continuity.update!(expires_at: now - 8.days)
    ready = Queue.new
    release = Queue.new
    ActiveRecord::Base.connection_handler.clear_active_connections!
    threads =
      Array.new(2) do |index|
        Thread.new do
          OpBaseAppRecord.connected_to(role: :writing) do
            OpBaseAppRecord.connection_pool.with_connection do |connection|
              ready << connection.select_value("SELECT pg_backend_pid()")
              release.pop
              if index.zero?
                begin
                  count = IdentityStepUpCeremonyTransactionPurger.new(now: now).call.fetch(:app)
                  (count == 1) ? :purged : :retained
                rescue ActiveRecord::InvalidForeignKey
                  :cleanup_refused
                end
              else
                begin
                  ClientAuthCeremonySession.find(continuity.id).revoke!
                  :revoked
                rescue ActiveRecord::RecordNotFound
                  :already_purged
                end
              end
            end
          end
        end
      end
    pids = nil
    results =
      ClientAuthCeremonySession.stub(:database_now, now) do
        Timeout.timeout(10) do
          pids = [ready.pop, ready.pop]
          2.times { release << true }
          threads.map(&:value)
        end
      end
    parent_present = ClientStepUpCeremonyTransaction.exists?(parent.id)
    continuity_present = ClientAuthCeremonySession.exists?(continuity.id)

    assert_equal 2, pids.uniq.length
    assert_equal parent_present, continuity_present
    if parent_present
      assert_includes [:retained, :cleanup_refused], results.first
      assert_equal :revoked, results.last
      assert_equal now.iso8601(6), continuity.reload.revoked_at.iso8601(6)
      assert_not continuity.active?(now: now)
      assert_raises(AuthCeremonySession::InvalidTransition) do
        continuity.record_authentication_evidence!(method: "passkey")
      end
    else
      assert_equal :purged, results.first
      assert_equal :already_purged, results.last
      assert_nil ClientAuthCeremonySession.find_by(id: continuity.id)
    end
  ensure
    if threads
      2.times { release << true }
      threads.each { |thread| thread.kill unless thread.join(10) }
    end
    if parent
      ClientAuthCeremonySession.where(step_up_ceremony_transaction_ref: parent.transaction_id).delete_all
      ClientStepUpCeremonyTransaction.where(id: parent.id).delete_all
    end
  end
end
