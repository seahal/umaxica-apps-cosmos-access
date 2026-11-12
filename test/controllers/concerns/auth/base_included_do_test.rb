# typed: false
# frozen_string_literal: true

require "test_helper"

module Auth
  class BaseIncludedDoTest < ActiveSupport::TestCase
    self.fixture_table_names = []

    test "authentication mode declarations work" do
      klass =
        Class.new(ApplicationController) do
          extend AuthenticationBase::ClassMethods
        end

      klass.declare_authentication_mode!(:open, only: :public)
      klass.declare_authentication_mode!(:private, only: :protected)
      klass.declare_authentication_mode!(:guest, only: :guest)

      rules = klass.local_authentication_mode_rules

      assert_equal 3, rules.length
      assert_equal :open, rules[0][:mode]
      assert_equal :private, rules[1][:mode]
      assert_equal :guest, rules[2][:mode]
    end

    test "skip_before_action :enforce_op_boundary_mode! raises SkipNotAllowedError" do
      klass =
        Class.new(ApplicationController) do
          extend AuthenticationBase::ClassMethods
        end

      assert_raises(AuthenticationBase::SkipNotAllowedError) do
        klass.skip_before_action :enforce_op_boundary_mode!
      end
    end

    test "skip_action_callback :enforce_op_boundary_mode! raises SkipNotAllowedError" do
      klass =
        Class.new(ApplicationController) do
          extend AuthenticationBase::ClassMethods
        end

      assert_raises(AuthenticationBase::SkipNotAllowedError) do
        klass.skip_action_callback(:process_action, :before, :enforce_op_boundary_mode!)
      end
    end

    test "skip_before_action allows other filters" do
      klass =
        Class.new(ApplicationController) do
          extend AuthenticationBase::ClassMethods

          before_action :some_callback

          define_method(:some_callback) do
            # Required by before_action
          end
        end

      assert_nothing_raised do
        klass.skip_before_action :some_callback
      end
    end
  end
end
