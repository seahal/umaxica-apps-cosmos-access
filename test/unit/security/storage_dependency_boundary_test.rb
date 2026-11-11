# frozen_string_literal: true

require "test_helper"

class StorageDependencyBoundaryTest < ActiveSupport::TestCase
  test "application does not load the Active Storage or Action Text engine" do
    application = Rails.root.join("config/application.rb").read

    assert_no_match(/active_storage\/engine/, application)
    assert_no_match(/action_text\/engine/, application)
  end

  test "bundle does not depend on Shrine or the S3 SDK" do
    gemfile = Rails.root.join("Gemfile").read
    lockfile = Rails.root.join("Gemfile.lock").read

    assert_no_match(/^\s*gem\s+["'](?:shrine|aws-sdk-s3)["']/, gemfile)
    assert_no_match(/^\s*(?:shrine|aws-sdk-s3)(?:\s|\()/, lockfile)
  end
end
