# typed: false
# frozen_string_literal: true

module AuthenticationBase
  extend ActiveSupport::Concern

  class InvalidPolicyError < StandardError; end

  class SkipNotAllowedError < StandardError; end

  AUTHENTICATION_MODE_RULES = Concurrent::Map.new

  class_methods do
    def authentication_mode_rules
      AUTHENTICATION_MODE_RULES.fetch_or_store(self) { [] }
    end

    def local_authentication_mode_rules
      authentication_mode_rules
    end

    def declare_authentication_mode!(mode, only: nil, except: nil, **options)
      mode = mode.to_sym
      raise InvalidPolicyError,
            "Invalid authentication mode: #{mode.inspect}" unless authentication_modes.include?(mode)

      rule = {
        mode: mode,
        only: Array(only).map(&:to_s).presence,
        except: Array(except).map(&:to_s).presence,
        options: options,
      }

      AUTHENTICATION_MODE_RULES[self] = authentication_mode_rules + [rule]
    end

    def authentication_mode_for(action)
      action = action.to_s

      authentication_mode_rules.reverse_each do |rule|
        next if rule[:only].present? && rule[:only].exclude?(action)
        next if rule[:except].present? && rule[:except].include?(action)

        return rule[:mode]
      end

      return const_get(:AUTHENTICATION_MODE, false) if const_defined?(:AUTHENTICATION_MODE, false)

      :deny_all
    end

    def authentication_modes
      %i(bare deny_all guest private open)
    end

    # --- Skip guardrails ---
    # Disallow removing enforce_op_boundary_mode! via skip_before_action.
    def skip_before_action(*filters, **options)
      # Note: In Ruby 4.0+/Rails 8+, some callers pass Hash as positional argument
      # instead of keyword arguments. Filter out non-symbol entries.
      flattened = filters.flatten
      action_names =
        flattened.filter_map do |filter|
          next unless filter.respond_to?(:to_sym) && !filter.is_a?(Hash)

          filter.to_sym
        end
      if action_names.include?(:enforce_op_boundary_mode!)
        raise SkipNotAllowedError, "skip_before_action :enforce_op_boundary_mode! is prohibited (#{name})"
      end

      super
    end

    # Some code uses skip_action_callback, so lock this down too.
    def skip_action_callback(*args, **kwargs)
      # skip_action_callback(:process_action, :before, :enforce_op_boundary_mode!)
      if args.map(&:to_sym).include?(:enforce_op_boundary_mode!)
        raise SkipNotAllowedError, "skip_action_callback :enforce_op_boundary_mode! is prohibited (#{name})"
      end

      super
    end

    private :authentication_mode_rules, :authentication_modes
  end
end
