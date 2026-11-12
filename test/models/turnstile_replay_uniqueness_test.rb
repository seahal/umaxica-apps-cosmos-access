# frozen_string_literal: true

require "test_helper"
require "concurrent/executor/simple_executor_service"
require "timeout"

class TurnstileReplayUniquenessTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "normal replay is invalid while direct SQL remains protected" do
    attributes = { ceremony_id: SecureRandom.uuid, token_digest: SecureRandom.hex(32), expires_at: 15.minutes.from_now }
    TurnstileReplay.create!(attributes)
    duplicate = TurnstileReplay.new(attributes)

    assert_not duplicate.valid?
    assert duplicate.errors.of_kind?(:token_digest, :taken)
    assert_raises(ActiveRecord::RecordInvalid) { duplicate.save! }
    assert_raises(ActiveRecord::RecordNotUnique) do
      TurnstileReplay.transaction(requires_new: true) { TurnstileReplay.insert_all!([attributes]) }
    end
    assert_equal 1, TurnstileReplay.where(token_digest: attributes[:token_digest]).count
  end
end

class TurnstileReplayUniquenessConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "simultaneous SQL consumption has exactly one winner" do
    digest = SecureRandom.hex(32)
    ready = Queue.new
    release = Queue.new
    workers =
      2.times.map do
        Concurrent::Future.execute(executor: Concurrent::SimpleExecutorService.new) do
          TurnstileReplay.connection_pool.with_connection do |connection|
            ready << connection.select_value("SELECT pg_backend_pid()")
            release.pop
            TurnstileReplay.insert_all!(
              [{ ceremony_id: SecureRandom.uuid,
                 token_digest: digest,
                 expires_at: 15.minutes.from_now, }],
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
    assert_equal 1, TurnstileReplay.where(token_digest: digest).count
  ensure
    2.times { release << true } if release
    workers&.each { |worker| worker.wait(10) }
    TurnstileReplay.where(token_digest: digest).delete_all if digest
  end
end
