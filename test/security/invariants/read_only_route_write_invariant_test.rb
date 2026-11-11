# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  module Invariants
    class ReadOnlyRouteWriteInvariantTest < ActionDispatch::IntegrationTest
      test "the unknown-host root performs no writes" do
        observed_writes = []
        callback =
          lambda do |_name, _started, _finished, _unique_id, payload|
            sql = payload[:sql].to_s.squish
            next unless sql.match?(/\A(?:INSERT|UPDATE|DELETE)\b/i)
            next if sql.match?(/\A(?:INSERT|UPDATE|DELETE)\s+"?ar_internal_metadata"?\b/i)
            next if sql.match?(/\A(?:INSERT|UPDATE|DELETE)\s+"?schema_migrations"?\b/i)

            observed_writes << sql
          end

        { "GET" => :get, "HEAD" => :head }.each do |method_name, method|
          reset!
          host! "unregistered.invalid"
          observed_writes.clear
          ActiveSupport::Notifications.subscribed(callback, "sql.active_record") do
            public_send(method, "/", params: { ri: "jp" })
          end

          assert_response :not_found, "#{method_name} unknown-host root"
          assert_empty observed_writes, "#{method_name} unknown-host root must not persist state"
        end
      end
    end
  end
end
