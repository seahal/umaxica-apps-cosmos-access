# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class DatabasePasswordConfigTest < ActiveSupport::TestCase
  test "development queue pools can serve every Solid Queue worker thread" do
    configurations = Rails.application.config.database_configuration.fetch("development")
    configuration = configurations.fetch("queue")

    assert_operator configuration.fetch("pool"), :>=, 5, "queue"
  end

  test "no Solid Cache connection remains and Solid Queue defines no read replica" do
    Rails.application.config.database_configuration.each_value do |configurations|
      assert_not configurations.key?("cache")
      assert_not configurations.key?("cache_replica")
      assert_not configurations.key?("queue_replica")
    end
  end

  test "production database is unconfigured and application boot fails explicitly" do
    database_yml = Rails.root.join("config/database.yml").read
    application_config = Rails.root.join("config/application.rb").read

    assert_empty Rails.application.config.database_configuration.fetch("production")
    assert_includes application_config,
                    'raise KeyError, "Production database is not configured; ' \
                    'choose a provider before booting production."'
    assert_includes database_yml, "production: {}"
    assert_not_includes database_yml, "production_value"
  end
end
