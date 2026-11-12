# frozen_string_literal: true

require "test_helper"
require "concurrent/executor/simple_executor_service"
require "timeout"

class OpStepUpPasskeyReferenceRaceTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = %w(client_tokens operator_tokens client_device_sessions operator_device_sessions)

  [
    [ClientStepUpSession, ClientStepUpCeremonyTransaction, "app", :user_token],
    [OperatorStepUpSession, OperatorStepUpCeremonyTransaction, "org", :staff_token],
  ].each do |session_model, transaction_model, realm, token_key|
    test "#{realm} concurrent SQL challenge references retain one database winner" do
      tokens =
        (realm == "app") ? [client_tokens(:one), client_tokens(:two)] :
               [operator_tokens(:one), operator_tokens(:two)]
      transactions = []
      sessions =
        tokens.map do |token|
          transaction = transaction_model.create_transaction!(
            actor_ref: "historical-actor", session_ref: token.public_id, required_scope: "settings_passkey",
            required_aal: "none", allowed_methods: ["passkey"], return_to: "/visa",
          )
          transactions << transaction
          session_model.create!(
            token_key => token, :step_up_ceremony_transaction_ref => transaction.transaction_id,
            :scope => transaction.required_scope, :return_to => transaction.return_to,
            :status => "PENDING", :discard_at => transaction.expires_at,
          )
        end
      reference = sessions.first.issue_bound_passkey_challenge!(
        transaction: transactions.first, challenge: "first", rp_id: "app.example", origin: "https://app.example",
      )
      fields = %w(passkey_challenge passkey_challenge_ref passkey_rp_id passkey_origin
                  passkey_challenge_expires_at passkey_challenge_consumed_at)
      attributes = sessions.first.reload.attributes.slice(*fields)
      sessions.first.update!(fields.index_with { nil })
      ready = Queue.new
      release = Queue.new
      workers =
        sessions.map do |session|
          Concurrent::Future.execute(executor: Concurrent::SimpleExecutorService.new) do
            session_model.connection_pool.with_connection do |connection|
              ready << connection.select_value("SELECT pg_backend_pid()")
              release.pop
              session_model.where(id: session.id).update_all(attributes)
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
      assert_equal 1, session_model.where(passkey_challenge_ref: reference).count
    ensure
      2.times { release << true } if release
      workers&.each { |worker| worker.wait(10) }
      session_model.where(id: sessions.map(&:id)).delete_all if sessions
      transaction_model.where(id: transactions.map(&:id)).delete_all if transactions
    end
  end
end
