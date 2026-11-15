# frozen_string_literal: true

require "test_helper"

class ClientSecretLifetimesValueTest < ActiveSupport::TestCase
  test "each configured lifetime requires a positive integer number of seconds" do
    accessors = %w(
      APP_SECRET_ISSUANCE_TTL_SECONDS
      APP_SECRET_PURGE_DELAY_SECONDS
      APP_SECRET_PROOF_RETENTION_SECONDS
      APP_SECRET_OUTBOX_RETENTION_SECONDS
    ).zip(%i(issuance_ttl purge_delay proof_retention outbox_retention))

    accessors.each do |environment_name, accessor|
      configured_fetch =
        lambda do |key|
          raise KeyError, key unless key == environment_name

          "1"
        end

      ENV.stub(:fetch, configured_fetch) do
        assert_equal 1.second, ClientSecretLifetimesValue.public_send(accessor), environment_name
      end

      ENV.stub(:fetch, ->(key) { raise KeyError, key }) do
        assert_raises(KeyError, environment_name) { ClientSecretLifetimesValue.public_send(accessor) }
      end

      ["0", "-1", "not-a-number"].each do |configured_value|
        ENV.stub(:fetch, ->(_key) { configured_value }) do
          assert_raises(ArgumentError, "#{environment_name}=#{configured_value}") do
            ClientSecretLifetimesValue.public_send(accessor)
          end
        end
      end
    end
  end
end
