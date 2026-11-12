# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthenticationBaseBranchCoverageMoreTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  class Harness < ApplicationController
    include AuthenticationBase
  end

  test "authentication mode and filter guards skip ineligible rules" do
    klass = Class.new(Harness)
    klass.declare_authentication_mode!(:guest, only: :allowed)

    assert_equal :deny_all, klass.authentication_mode_for(:other)
    klass.skip_before_action({ enforce_op_boundary_mode!: true })
    assert_raises(AuthenticationBase::SkipNotAllowedError) { klass.skip_action_callback(:process_action, :before, :enforce_op_boundary_mode!) }
  end
end
