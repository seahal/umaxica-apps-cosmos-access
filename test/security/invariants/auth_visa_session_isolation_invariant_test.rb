# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthVisaSessionIsolationInvariantTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  SHARED_PRESENTATION_SESSION_KEYS = %w(inertia_clear_history).freeze

  test "Visa controllers never read Auth-owned session state" do
    auth_files = Dir.glob("app/controllers/auth/**/*.rb")
    visa_files = Dir.glob("app/controllers/visa/**/*.rb")
    auth_session_keys = auth_files.flat_map do |path|
      File.read(path).scan(/\bsession\s*\[\s*:(\w+)\s*\]\s*(?:\|\|=|(?<!=)=(?!=))/).flatten
    end.uniq - SHARED_PRESENTATION_SESSION_KEYS
    offenders =
      visa_files.flat_map do |path|
        File.read(path).lines.each_with_index.filter_map do |line, index|
          key =
            auth_session_keys.find do |session_key|
              escaped_key = Regexp.escape(session_key)
              line.match?(/\bsession\s*\[\s*:#{escaped_key}\b/) ||
                line.match?(/\bsession\s*\.dig\s*\(\s*:#{escaped_key}\b/)
            end
          "#{path}:#{index + 1}: Auth session key :#{key}" if key
        end
      end

    assert_includes auth_session_keys, "auth_app_up_sequence_id"
    assert_empty offenders, "Visa must not consume Auth-owned Rails session keys:\n#{offenders.join("\n")}"
  end
end
