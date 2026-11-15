# typed: false
# frozen_string_literal: true

require "test_helper"

# Mass unit tops for still-cold raise/return arms that do not need the request stack.
class BranchCoverageBatch24MassEasyArmsTest < ActiveSupport::TestCase
  self.fixture_table_names = []
  test "RedirectsExternalTargetResolver refuses blank origins" do
    resolver = RedirectsExternalTargetResolver.new(:rp_app, path: "/", query: {}, source: :explicit_external)
    resolver.define_singleton_method(:origin_for) { |_| "" }

    assert_equal "invalid_origin", resolver.call.failure_reason
  end
end
