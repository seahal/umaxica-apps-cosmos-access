# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

module Security
  module Invariants
    class ControllerLifecycleOrderInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      RETAINED_AUTHORITY_CONTROLLERS = [
        Visa::App::AuthorityController,
        Visa::Org::AuthorityController,
      ].freeze

      REQUIRED_ORDER = %i(
        apply_default_no_store
        enforce_fqdn_availability!
        require_authenticity_token_for_unsafe_request!
        verify_jump_return_rt!
        enforce_op_boundary_mode!
      ).freeze

      test "Visa authorities enforce cache host CSRF and OP boundary in reviewed order" do
        violations =
          RETAINED_AUTHORITY_CONTROLLERS.filter_map do |controller|
            filters = before_filters_for(controller)
            required_order = REQUIRED_ORDER
            missing = required_order - filters
            out_of_order = out_of_order_filters(filters, required_order)
            next if missing.empty? && out_of_order.empty?

            "#{controller.name}: missing=#{missing.inspect}, out_of_order=#{out_of_order.inspect}"
          end

        assert_empty violations, "Authentication lifecycle callback order drifted:\n#{violations.join("\n")}"
      end

      test "Visa authorities clear request actor state around each request" do
        violations =
          RETAINED_AUTHORITY_CONTROLLERS.filter_map do |controller|
            around_filters =
              controller._process_action_callbacks.filter_map do |callback|
                callback.filter if callback.kind == :around
              end
            next if around_filters.include?(:with_request_actor_lifecycle)

            "#{controller.name}: around filters=#{around_filters.inspect}"
          end

        assert_empty violations, "Request actor cleanup is required:\n#{violations.join("\n")}"
      end

      private

      def before_filters_for(controller)
        controller._process_action_callbacks.filter_map do |callback|
          callback.filter if callback.kind == :before
        end
      end

      def out_of_order_filters(filters, required_order)
        positions =
          required_order.filter_map do |filter|
            index = filters.index(filter)
            [filter, index] if index
          end

        positions.each_cons(2).filter_map do |(left_filter, left_index), (right_filter, right_index)|
          next if left_index < right_index

          "#{left_filter} must run before #{right_filter}"
        end
      end
    end
  end
end
