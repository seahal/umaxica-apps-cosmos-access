# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class StandardErrorRescueInventoryTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  REVIEWED_RESCUES = {
    "app/controllers/concerns/authentication_logout_current_session.rb" => {
      count: 2,
      classification: "logout transaction boundary resolves commit outcome and raises when it remains unknown",
    },
    "app/controllers/concerns/social_callback_guard.rb" => {
      count: 1,
      classification: "callback boundary; clears state and re-raises",
    },
    "app/controllers/concerns/social_omniauth_callback_flow.rb" => {
      count: 1,
      classification: "callback boundary; clears intent and re-raises",
    },
    "app/controllers/concerns/authentication_audit_writer.rb" => {
      count: 3,
      classification: "best-effort audit side effect with outbox/fallback recovery",
    },
  }.freeze

  test "reviewed StandardError rescues stay classified" do
    offenders =
      REVIEWED_RESCUES.filter_map do |path, expected|
        actual = rescue_count(path)
        next if actual == expected.fetch(:count) && expected.fetch(:classification).present?

        "#{path}: expected #{expected.fetch(:count)}, got #{actual} (#{expected.fetch(:classification)})"
      end

    assert_empty offenders, "Reviewed StandardError rescue inventory changed:\n#{offenders.join("\n")}"
  end

  private

  def rescue_count(path)
    Rails.root.join(path).read.scan(/\brescue\s+StandardError\b/).size
  end
end
