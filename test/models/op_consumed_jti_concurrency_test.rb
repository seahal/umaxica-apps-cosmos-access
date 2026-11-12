# frozen_string_literal: true

require "test_helper"
require "timeout"

class OpConsumedJtiConcurrencyTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  self.use_transactional_tests = false

  test "concurrent consumers commit exactly one digest independently in each realm" do
    client_id = "race-#{SecureRandom.hex(12)}"
    workers = []

    [OpAppConsumedJti, OpOrgConsumedJti].each do |model|
      ready = Queue.new
      start = Queue.new
      expires_at = 1.minute.from_now
      workers =
        Array.new(2) do
          Thread.new do
            model.connection_pool.with_connection do
              # Both validators see an empty committed snapshot; only the unique index arbitrates.
              model.transaction(isolation: :repeatable_read) do
                assert_equal 0, model.where(client_id: client_id).count
                ready << true
                start.pop
                model.consume!(
                  purpose: "logout_token", issuer: "https://op.example.test",
                  client_id: client_id, jti: "concurrent-jti", expires_at: expires_at,
                )
              end
            end
          end
        end
      Timeout.timeout(10) { 2.times { ready.pop } }
      2.times { start << true }

      workers.each { |worker| assert worker.join(10), "consumer did not finish" }

      assert_equal [false, true], workers.map(&:value).sort_by(&:to_s)
      assert_equal 1, model.where(client_id: client_id).count
    end
  ensure
    workers.each { |worker| worker.kill if worker.alive? }
    # These are only this test's committed rows in the fixed test databases.
    OpAppConsumedJti.where(client_id: client_id).delete_all
    OpOrgConsumedJti.where(client_id: client_id).delete_all
  end
end
