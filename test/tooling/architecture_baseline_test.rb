# typed: false
# frozen_string_literal: true

require "minitest/autorun"
require "active_support"
require "active_support/test_case"
require_relative "../../lib/architecture_baseline"

# Ratchet for the Umaxica architecture cops. RuboCop reports all findings directly; this test keeps
# the per-file debt count from growing while existing findings are removed.
class ArchitectureBaselineTest < ActiveSupport::TestCase
  def test_no_file_exceeds_its_recorded_architecture_debt
    measured = ArchitectureBaseline.measure
    recorded = ArchitectureBaseline.recorded

    ArchitectureBaseline::COPS.each do |cop|
      recorded_files = recorded.fetch(cop)

      measured.fetch(cop).each do |path, count|
        allowed = recorded_files.fetch(path, 0)

        assert_operator count, :<=, allowed,
                        "#{path} has #{count} #{cop} offenses but the baseline allows #{allowed}. " \
                        "Fix the new violation; do not regenerate the baseline to hide it."
      end
    end
  end

  def test_rubocop_todo_does_not_exist
    assert_not File.exist?(ArchitectureBaseline::ROOT.join(".rubocop_todo.yml"))
  end

  def test_baseline_does_not_list_resolved_files
    measured = ArchitectureBaseline.measure

    ArchitectureBaseline::COPS.each do |cop|
      stale = ArchitectureBaseline.recorded.fetch(cop).keys - measured.fetch(cop).keys

      assert_empty stale,
                   "#{cop} baseline lists files with no remaining offenses. " \
                   "Run bin/rails architecture:baseline to drop them."
    end
  end
end
