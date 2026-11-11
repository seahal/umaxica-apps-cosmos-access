# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  class SurfaceChromeRestrictedModeInvariantTest < ActiveSupport::TestCase
    self.fixture_table_names = []

    test "only the shared chrome produces the restricted mode indicator" do
      producers =
        Rails.root.glob("app/controllers/**/*.rb").select do |path|
          next false if path.to_s.end_with?("app/controllers/concerns/surface_chrome.rb")

          path.read.match?(/^\s*restricted_mode:/)
        end

      assert_empty producers.map { |path| path.relative_path_from(Rails.root).to_s },
                   "Restricted Mode is session state published once by SurfaceChrome, not page props"

      page_producers = Rails.root.glob("src/pages/**/*.tsx").select { |path| path.read.include?("restricted_mode:") }

      assert_empty page_producers.map { |path| path.relative_path_from(Rails.root).to_s }
    end
  end
end
