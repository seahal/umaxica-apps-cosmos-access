# frozen_string_literal: true

require "test_helper"
require "concurrent/executor/simple_executor_service"
require "timeout"

class ClientOidcSecretFlowUniquenessTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "historical secret flow belongs to at most one authorization transaction" do
    now = ClientSignInFlow.database_now
    flow = ClientSignInFlow.create!(nonce_digest: SecureRandom.hex(32), issued_at: now, expires_at: now + 5.minutes)
    transactions =
      2.times.map do
        ClientOidcAuthorizationTransaction.create_transaction!(
          surface: "app", intent: "sign_in", client_id: "core-app-jp", redirect_uri: "https://example.com/callback",
          response_type: "code", scope: "openid", state: "state", nonce: "nonce",
          code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM", code_challenge_method: "S256",
          login_challenge: SecureRandom.base58(32), login_challenge_expires_at: now + 5.minutes,
          expires_at: now + 5.minutes,
        )
      end

    assert_nil transactions.first.secret_sign_in_flow_id
    assert_nil transactions.last.secret_sign_in_flow_id
    transactions.first.update!(secret_sign_in_flow: flow)
    transactions.last.secret_sign_in_flow = flow

    assert_not transactions.last.valid?
    assert transactions.last.errors.of_kind?(:secret_sign_in_flow_id, :taken)
    assert_raises(ActiveRecord::RecordInvalid) { transactions.last.save! }
    assert_raises(ActiveRecord::RecordNotUnique) do
      ClientOidcAuthorizationTransaction.transaction(requires_new: true) do
        ClientOidcAuthorizationTransaction.where(id: transactions.last.id).update_all(secret_sign_in_flow_id: flow.id)
      end
    end
    assert_raises(ActiveRecord::InvalidForeignKey) do
      ClientOidcAuthorizationTransaction.transaction(requires_new: true) do
        ClientOidcAuthorizationTransaction.where(id: transactions.last.id).update_all(secret_sign_in_flow_id: -1)
      end
    end

    assert_nil transactions.last.reload.secret_sign_in_flow_id
    assert_equal flow.id, transactions.first.reload.secret_sign_in_flow_id
    error =
      assert_raises(ActiveRecord::StatementInvalid) do
        ClientSignInFlow.transaction(requires_new: true) { ClientSignInFlow.where(id: flow.id).delete_all }
      end
    assert_instance_of PG::RestrictViolation, error.cause
    assert_predicate flow.reload, :persisted?
  end
end

class ClientOidcSecretFlowUniquenessConcurrencyTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  self.use_transactional_tests = false

  test "two independent authorization writers cannot claim the same historical flow" do
    now = ClientSignInFlow.database_now
    flow = ClientSignInFlow.create!(nonce_digest: SecureRandom.hex(32), issued_at: now, expires_at: now + 5.minutes)
    transactions =
      2.times.map do
        ClientOidcAuthorizationTransaction.create_transaction!(
          surface: "app", intent: "sign_in", client_id: "core-app-jp", redirect_uri: "https://example.com/callback",
          response_type: "code", scope: "openid", state: "state", nonce: "nonce",
          code_challenge: "E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM", code_challenge_method: "S256",
          login_challenge: SecureRandom.base58(32), login_challenge_expires_at: now + 5.minutes,
          expires_at: now + 5.minutes,
        )
      end
    ready = Queue.new
    release = Queue.new
    workers =
      transactions.map do |transaction|
        Concurrent::Future.execute(executor: Concurrent::SimpleExecutorService.new) do
          ClientOidcAuthorizationTransaction.connection_pool.with_connection do |connection|
            ready << connection.select_value("SELECT pg_backend_pid()")
            release.pop
            ClientOidcAuthorizationTransaction.where(id: transaction.id).update_all(secret_sign_in_flow_id: flow.id)
            :claimed
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
    assert_equal %i(claimed conflict), outcomes.sort
    assert_equal 1, ClientOidcAuthorizationTransaction.where(secret_sign_in_flow_id: flow.id).count
  ensure
    2.times { release << true } if release
    workers&.each { |worker| worker.wait(10) }
    if transactions
      ClientOidcAuthorizationTransaction.where(id: transactions.map(&:id)).update_all(secret_sign_in_flow_id: nil)
      ClientOidcAuthorizationTransaction.where(id: transactions.map(&:id)).delete_all
    end
    ClientSignInFlow.where(id: flow.id).delete_all if flow
  end
end
