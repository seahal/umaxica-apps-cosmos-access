# typed: false
# frozen_string_literal: true

require "test_helper"

class ControllerBaseInheritanceTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  BARE_CONTROLLERS = [
    Auth::App::BareController,
    Auth::Org::BareController,
    Visa::App::BareController,
    Visa::Org::BareController,
  ].freeze

  AUTH_APPLICATION_CONTROLLERS = [
    Auth::App::ApplicationController,
    Auth::Org::ApplicationController,
  ].freeze

  VISA_AUTHORITY_CONTROLLERS = [
    Visa::App::AuthorityController,
    Visa::Org::AuthorityController,
  ].freeze

  test "bare controllers inherit directly from ActionController base" do
    BARE_CONTROLLERS.each do |controller|
      assert_equal ActionController::Base, controller.superclass,
                   "#{controller.name} must bypass ApplicationController and its callbacks"
      if controller.module_parent.const_defined?(:ApplicationController, false)
        assert_not_operator controller, :<, controller.module_parent::ApplicationController
      end

      assert_includes controller.ancestors, RateLimit
    end
  end

  test "bare controller source does not normalize inheritance to application controller" do
    violations =
      Rails.root.glob("app/controllers/**/bare_controller.rb").filter_map do |path|
        content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)
        path.relative_path_from(Rails.root).to_s if content.include?("class BareController < ApplicationController")
      end

    assert_empty violations,
                 "BareController must inherit ActionController::Base directly:\n#{violations.join("\n")}"
  end

  test "Auth application controllers inherit directly from ActionController base" do
    AUTH_APPLICATION_CONTROLLERS.each do |controller|
      assert_equal ActionController::Base, controller.superclass
      assert_includes controller.ancestors, RateLimit
    end
  end

  test "Visa authority controllers inherit from the shared application controller" do
    VISA_AUTHORITY_CONTROLLERS.each do |controller|
      assert_equal ::ApplicationController, controller.superclass
      assert_includes controller.ancestors, RateLimit
    end
  end

  test "BARE_CONTROLLERS stays in sync with retained bare controller files" do
    discovered =
      Rails.root.glob("app/controllers/**/bare_controller.rb").map do |path|
        relative = path.relative_path_from(Rails.root.join("app/controllers"))
        relative.to_s.delete_suffix(".rb").camelize.constantize
      end.sort_by(&:name)

    assert_equal BARE_CONTROLLERS.sort_by(&:name), discovered,
                 "BARE_CONTROLLERS must list every retained bare_controller.rb"
  end

  test "retained Auth and Visa namespaces have no open controller compatibility bases" do
    [Auth::App, Auth::Org, Visa::App, Visa::Org].each do |namespace|
      assert_not namespace.const_defined?(:OpenController, false), namespace.name
    end
  end

  test "check namespace controllers do not inherit checkpoint namespace implementations" do
    violations =
      Rails.root.glob("app/controllers/auth/**/*_controller.rb").filter_map do |path|
        content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)
        next unless content.match?(/class\s+.*::Checks?::?.*Controller\s*<\s*.*::Checkpoints?::?.*Controller/)

        path.relative_path_from(Rails.root).to_s
      end

    assert_empty violations,
                 "Check namespace controllers must not inherit stale Checkpoint implementations:\n" \
                 "#{violations.join("\n")}"
  end

  test "application routes reference loadable controller classes" do
    missing =
      Rails.application.routes.routes.filter_map do |route|
        controller = route.defaults[:controller]
        next if controller.blank?

        class_name = "#{controller.camelize}Controller"
        class_name.constantize
        nil
      rescue NameError
        class_name
      end.uniq.sort

    framework_prefixes = /\A(?:ActionMailbox|MissionControl|Turbo)::/
    missing.reject! { |class_name| class_name.match?(framework_prefixes) }

    assert_empty missing, "Routes reference missing controller classes:\n#{missing.join("\n")}"
  end
end
