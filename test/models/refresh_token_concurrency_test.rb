# frozen_string_literal: true

require "test_helper"

class RefreshTokenConcurrencyTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  self.fixture_table_names = []

  test "concurrent refresh attempts cannot both rotate the same client token" do
    user_id = 1_000_000_000_000 + SecureRandom.random_number(1_000_000_000)
    device_session = ClientDeviceSession.create!(
      user_id: user_id,
      principal_public_id: PublicId.generate,
      public_id: PublicId.generate,
      status_id: DeviceSessionable::STATUS_ACTIVE,
    )
    token = ClientToken.create!(
      authentication_epoch: 0,
      device_session: device_session,
      user_id: user_id,
      discard_at: 1.day.from_now,
      purge_eligible_at: 2.days.from_now,
    )
    refresh = token.rotate_refresh_token!
    digest = ClientToken.digest_refresh_token(ClientToken.parse_refresh_token(refresh).last)
    ready = Queue.new
    release = Queue.new
    results = Queue.new

    threads =
      2.times.map do
        Thread.new do
          ActiveRecord::Base.connection_pool.with_connection do
            ready << true
            release.pop
            result = ClientToken.rotate_refresh!(presented_refresh_digest: digest, now: Time.current)
            results << { status: result.fetch(:status), token_id: result[:token]&.id }
          rescue StandardError => e
            results << { status: :error, error: "#{e.class}: #{e.message}" }
          end
        end
      end

    2.times { ready.pop }
    2.times { release << true }
    threads.each(&:join)
    outcomes = 2.times.map { results.pop }

    assert_equal 2, outcomes.size
    assert_equal 1, outcomes.count { |result| result.fetch(:status) == :rotated }, outcomes.inspect
    assert_equal 1, outcomes.count { |result| result.fetch(:status).in?(%i(replay invalid)) }, outcomes.inspect

    family = ClientToken.where(refresh_token_family_id: token.refresh_token_family_id)

    assert_equal 2, family.count
    assert_equal 1, family.where(rotated_at: nil).count
    assert_predicate token.reload.rotated_at, :present?
  ensure
    ActiveRecord::Base.connection_handler.clear_active_connections!
    ClientToken.where(device_session_id: device_session&.id).delete_all
    ClientDeviceSession.where(id: device_session&.id).delete_all
  end
end
