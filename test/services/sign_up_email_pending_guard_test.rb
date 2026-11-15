# typed: false
# frozen_string_literal: true

require "test_helper"

class SignUpEmailPendingGuardTest < ActiveSupport::TestCase
  test "an email digest is locked on its owning transaction before the block runs" do
    namespace = SignUpEmailPendingGuard::EMAIL_NAMESPACE
    lock_sql = /SELECT pg_advisory_xact_lock\(#{expected_lock_key(namespace, "email-digest")}\)/
    seen_queries = []
    result = nil

    with_lock_query_capture(seen_queries) do
      result =
        SignUpEmailPendingGuard.with_lock(address_digest: "email-digest", model_class: ClientOidcConnection) do
          assert seen_queries.any? { |sql| sql.match?(lock_sql) }
          :registered
        end
    end

    assert_equal :registered, result
    assert_equal 1, seen_queries.count { |sql| sql.match?(lock_sql) }
  end

  test "a telephone digest can use an explicit namespace on the provided connection" do
    connection = ClientOidcConnection.connection
    lock_sql = /SELECT pg_advisory_xact_lock\(#{expected_lock_key("account:telephone", "telephone-digest")}\)/
    seen_queries = []
    result = nil

    with_lock_query_capture(seen_queries) do
      result =
        SignUpEmailPendingGuard.with_lock(
          number_digest: "telephone-digest", namespace: "account:telephone", connection: connection,
        ) do
          assert seen_queries.any? { |sql| sql.match?(lock_sql) }
          :registered
        end
    end

    assert_equal :registered, result
    assert_equal 1, seen_queries.count { |sql| sql.match?(lock_sql) }
  end

  test "missing lock inputs fail before the registration block runs" do
    yielded = false

    assert_raises(ArgumentError) do
      SignUpEmailPendingGuard.with_lock(model_class: ClientOidcConnection) { yielded = true }
    end
    assert_raises(ArgumentError) do
      SignUpEmailPendingGuard.with_lock(address_digest: "email-digest", model_class: ClientOidcConnection)
    end
    assert_raises(ArgumentError) do
      SignUpEmailPendingGuard.with_lock(address_digest: "email-digest") { yielded = true }
    end

    assert_not yielded
  end

  private

  def expected_lock_key(namespace, digest)
    value = Digest::SHA256.hexdigest("#{namespace}:#{digest}")[0, 16].to_i(16)
    value -= 1 << 64 if value >= 1 << 63
    value
  end

  def with_lock_query_capture(seen_queries)
    subscriber =
      lambda do |_name, _start, _finish, _id, payload|
        seen_queries << payload[:sql] if payload[:sql]&.include?("pg_advisory_xact_lock")
      end

    ActiveSupport::Notifications.subscribed(subscriber, "sql.active_record") { yield }
  end
end
