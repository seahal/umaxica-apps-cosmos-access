# typed: false
# frozen_string_literal: true

require "test_helper"

module Security
  # D-59 (two.md section 3.5): the Sign Entry classification is a static declaration, and the
  # reachable Auth routes must equal the declared set. An action with no declaration is a failing
  # guard here, never a silent exclusion at request time.
  class SignEntryClassificationGuardTest < ActiveSupport::TestCase
    self.fixture_table_names = []

    AUTH_CONTROLLER_PREFIX = "auth/"
    # Reachable interactive flows whose classification has to name the flow it continues.
    SIGN_IN_CLASS_PREFIXES = %w(Auth::App::Sign::In Auth::Org::Sign::In Auth::App::Web::V0::In).freeze
    SIGN_UP_CLASS_PREFIXES = %w(Auth::App::Sign::Up Auth::Org::Sign::Up).freeze

    test "every reachable Auth route resolves to a declared classification" do
      missing =
        auth_routes.filter_map do |route|
          controller_class = controller_class_for(route)
          if controller_class.nil?
            next "#{route.verb.presence || "ANY"} #{route.path.spec} => " \
                 "#{route.defaults[:controller]}##{route.defaults[:action]}: controller not found"
          end

          action = route.defaults[:action].to_sym
          next if classification_for(controller_class, action)

          "#{route.verb.presence || "ANY"} #{route.path.spec} => " \
            "#{controller_class.name}##{action}"
        end

      assert_empty missing,
                   "Reachable Auth actions must declare a Sign Entry classification:\n#{missing.join("\n")}"
    end

    test "unavailable ceremonies have an explicit exclusion and no standby bypass" do
      [Auth::App::UnavailableCeremoniesController, Auth::Org::UnavailableCeremoniesController].each do |controller|
        assert_equal :excluded, controller.sign_entry_classification_value
        assert_match(/unavailable/, controller.sign_entry_classification_reason)
        assert_predicate controller, :sign_entry_classification_value?
        assert_predicate controller, :sign_entry_classification_reason?
        assert_not_predicate controller, :sign_entry_standby_only?
      end
      assert_empty SignEntryClassification::STANDBY_ONLY_CONTROLLERS
    end

    test "every Auth controller declares one of the closed classifications" do
      invalid =
        auth_controller_classes.filter_map do |controller_class|
          value = controller_class.sign_entry_classification_value
          next "#{controller_class.name}: undeclared" if value.nil?
          unless controller_class.sign_entry_classification_value? == value.present?
            next "#{controller_class.name}: classification predicate does not match its declaration"
          end

          unless SignEntryClassification::CLASSIFICATIONS.include?(value)
            next "#{controller_class.name}: unsupported #{value.inspect}"
          end

          reason = controller_class.sign_entry_classification_reason
          unless controller_class.sign_entry_classification_reason? == reason.present?
            next "#{controller_class.name}: reason predicate does not match its declaration"
          end
          if value == :excluded && reason.blank?
            next "#{controller_class.name}: excluded without a reason"
          end

          overrides = controller_class.sign_entry_classification_overrides
          if overrides.value?(:excluded) && reason.blank?
            next "#{controller_class.name}: excluded action without a reason"
          end
          if value != :excluded && !overrides.value?(:excluded) && !controller_class.sign_entry_standby_only? &&
              reason.present?
            next "#{controller_class.name}: reason on a governed flow"
          end

          nil
        end

      assert_empty invalid, "Auth controllers must declare a valid classification:\n#{invalid.join("\n")}"
    end

    test "interactive classes are classified for the flow their namespace names" do
      mismatched =
        auth_controller_classes.filter_map do |controller_class|
          value = controller_class.sign_entry_classification_value
          next unless %i(sign_in sign_up).include?(value)

          expected =
            case value
            when :sign_in
              :sign_in if SIGN_IN_CLASS_PREFIXES.any? { |prefix| controller_class.name.start_with?(prefix) }
            when :sign_up
              :sign_up if SIGN_UP_CLASS_PREFIXES.any? { |prefix| controller_class.name.start_with?(prefix) }
            end
          next if expected == value

          "#{controller_class.name}: declared #{value.inspect}, namespace says #{expected.inspect}"
        end

      assert_empty mismatched,
                   "Sign In and Sign Up controllers must not carry the other flow's classification:\n" \
                   "#{mismatched.join("\n")}"
    end

    test "parent_intent resolves its flow from the verified parent, never request parameters" do
      source = Rails.root.join("app/controllers/concerns/sign_entry_sentry_enforcement.rb").read

      verified_parent_body = source[/def sign_entry_intent_from_verified_parent.*?^  end$/m]

      assert_not_nil verified_parent_body, "sign_entry_intent_from_verified_parent must stay the single parent resolver"
      assert_no_match(/\bparams\b/, verified_parent_body, "parent_intent must not read request parameters")

      request_flow_body = source[/def sign_entry_sentry_flow_for_request.*?^  end$/m]

      assert_not_nil request_flow_body
      assert_no_match(/\bparams\b/, request_flow_body, "the request classification must not read request parameters")
    end

    test "the classification set is closed and excluded requires a reason" do
      assert_equal %i(sign_in sign_up parent_intent excluded), SignEntryClassification::CLASSIFICATIONS

      assert_raises(SignEntryClassification::InvalidStandbyExceptionError) do
        Class.new do
          include SignEntryClassification

          sign_entry_classification! :sign_in, standby_only: true, reason: "standby"
        end
      end
      assert_raises(SignEntryClassification::InvalidStandbyExceptionError) do
        Class.new do
          include SignEntryClassification

          sign_entry_classification! :sign_up, standby_only: true, reason: "standby"
        end
      end
      assert_raises(SignEntryClassification::InvalidStandbyExceptionError) do
        Class.new do
          include SignEntryClassification

          sign_entry_classification! :sign_in, standby_only: "true"
        end
      end

      assert_raises(SignEntryClassification::UnsupportedClassificationError) do
        Class.new do
          include SignEntryClassification

          sign_entry_classification! :sign_on
        end
      end

      assert_raises(SignEntryClassification::MissingExcludedReasonError) do
        Class.new do
          include SignEntryClassification

          sign_entry_classification! :excluded
        end
      end

      assert_raises(SignEntryClassification::MissingExcludedReasonError) do
        Class.new do
          include SignEntryClassification

          sign_entry_classification! :sign_in, actions: { show: :excluded }
        end
      end

      controller_class =
        Class.new do
          include SignEntryClassification

          sign_entry_classification! :sign_in, reason: "health check", actions: { show: :excluded }
        end

      assert_equal :excluded, controller_class.sign_entry_classification_overrides[:show]
      assert_equal "health check", controller_class.sign_entry_classification_reason
    end

    test "a subclass inherits its class classification without inheriting parent action overrides" do
      parent =
        Class.new do
          include SignEntryClassification

          sign_entry_classification! :sign_in, reason: "parent entry", actions: { show: :excluded }
        end
      child = Class.new(parent)

      assert_equal :sign_in, child.sign_entry_classification_value
      assert_equal "parent entry", child.sign_entry_classification_reason
      assert_empty child.sign_entry_classification_overrides
      assert_not_predicate child, :sign_entry_standby_only?
    end

    test "a class without a declaration has no guessed sign entry classification" do
      controller_class = Class.new { include SignEntryClassification }

      assert_nil controller_class.sign_entry_classification_value
      assert_nil controller_class.sign_entry_classification_reason
      assert_empty controller_class.sign_entry_classification_overrides
      assert_not_predicate controller_class, :sign_entry_standby_only?
    end

    test "a declaration does not expose mutable class attribute writers" do
      controller_class =
        Class.new do
          include SignEntryClassification

          sign_entry_classification! :sign_in, reason: "entry"
        end

      assert_raises(NoMethodError) { controller_class.sign_entry_classification_value = :excluded }
      assert_not_respond_to controller_class, :sign_entry_classification!
    end

    private

    def auth_routes
      Rails.application.routes.routes.select do |route|
        route.defaults[:controller].to_s.start_with?(AUTH_CONTROLLER_PREFIX) &&
          route.defaults[:action].present?
      end
    end

    def controller_class_for(route)
      controller_name = route.defaults[:controller]
      return nil if controller_name.blank?

      "#{controller_name.camelize}Controller".safe_constantize
    end

    def classification_for(controller_class, action)
      controller_class.sign_entry_classification_overrides[action] ||
        controller_class.sign_entry_classification_value
    end

    def auth_controller_classes
      Rails.root.glob("app/controllers/auth/**/*_controller.rb").filter_map do |path|
        relative = path.relative_path_from(Rails.root.join("app/controllers")).to_s.delete_suffix(".rb")
        "#{relative.camelize}Controller".safe_constantize
      end.uniq
    end
  end
end
