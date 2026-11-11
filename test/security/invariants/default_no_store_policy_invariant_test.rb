# typed: false
# frozen_string_literal: true

require "test_helper"

# Auth and Visa own the retained browser surfaces and apply no-store before surface callbacks.
module Security
  module Invariants
    class DefaultNoStorePolicyInvariantTest < ActiveSupport::TestCase
      self.fixture_table_names = []

      POLICY_ROOTS = [
        Auth::App::ApplicationController,
        Auth::Org::ApplicationController,
        Auth::App::BareController,
        Auth::Org::BareController,
        Auth::App::Apple::NotificationsController,
        Visa::App::AuthorityController,
        Visa::Org::AuthorityController,
        Visa::App::BareController,
        Visa::Org::BareController,
        Visa::App::Api::V0::SensitiveAdmissionSessionsController,
        Visa::App::Api::V0::SensitiveAdmissionsController,
        Visa::App::Oauth::TokensController,
        Visa::App::Oauth::RevocationsController,
        Visa::Org::Api::V0::SensitiveAdmissionSessionsController,
        Visa::Org::Api::V0::SensitiveAdmissionsController,
        Visa::Org::Oauth::RevocationsController,
      ].freeze

      IN_SCOPE_NAMESPACES = %w(Auth Visa).freeze

      test "every policy root includes DefaultNoStore and runs it as its first before_action" do
        violations =
          POLICY_ROOTS.filter_map do |root|
            first = root._process_action_callbacks.find { |callback| callback.kind == :before }&.filter
            next if root.include?(DefaultNoStore) && first == :apply_default_no_store

            "#{root.name}: includes DefaultNoStore=#{root.include?(DefaultNoStore)}, " \
              "first before_action=#{first.inspect}"
          end

        assert_empty violations, violations.join("\n")
      end

      test "every controller beneath a policy root runs no-store first and the availability gate second" do
        violations =
          POLICY_ROOTS.flat_map do |root|
            [root, *root.descendants].filter_map do |controller|
              names = controller._process_action_callbacks.select { |callback| callback.kind == :before }.map(&:filter)
              expected =
                if controller.include?(FqdnAvailabilityGate)
                  %i(apply_default_no_store enforce_fqdn_availability!)
                else
                  %i(apply_default_no_store)
                end
              next if names.first(expected.size) == expected

              "#{controller.name}: first before_actions=#{names.first(3).inspect}"
            end
          end

        assert_empty violations,
                     "Re-prepend :apply_default_no_store after ensure_fqdn_gate_first!; never skip it:\n" \
                     "#{violations.join("\n")}"
      end

      test "every retained Auth and Visa controller root is covered by the policy" do
        surface_roots =
          ActionController::Base.descendants.select do |controller|
            next false unless controller.superclass == ActionController::Base

            namespace, _surface, leaf = controller.name.to_s.split("::")
            IN_SCOPE_NAMESPACES.include?(namespace) && %w(ApplicationController BareController).include?(leaf)
          end
        api_roots =
          ActionController::API.descendants.select do |controller|
            controller.superclass == ActionController::API &&
              IN_SCOPE_NAMESPACES.include?(controller.name.to_s.split("::").first)
          end
        missing = (surface_roots + api_roots) - POLICY_ROOTS

        assert_empty missing.map(&:name), "Policy roots without DefaultNoStore"
      end

      test "the repository-wide ApplicationController does not carry the policy" do
        assert_not ::ApplicationController.include?(DefaultNoStore)
      end

      test "DefaultNoStore is declared only by retained Auth and Visa policy roots" do
        declaring_files =
          Rails.root.glob("app/controllers/**/*.rb").select do |path|
            path.read.match?(/^\s*include ::DefaultNoStore\b/)
          end
        expected = POLICY_ROOTS.map { |root| Rails.root.join("app/controllers/#{root.name.underscore}.rb") }

        assert_equal expected.map(&:to_s).sort, declaring_files.map(&:to_s).sort
      end

      test "no controller skips the default no-store callback" do
        offenders =
          Rails.root.glob("app/**/*.rb").select do |path|
            path.readlines.any? do |line|
              !line.lstrip.start_with?("#") && line.match?(/skip_(before_)?action\s*\(?\s*:apply_default_no_store\b/)
            end
          end

        assert_empty offenders.map { |path| path.relative_path_from(Rails.root).to_s }
      end

      test "DefaultNoStore registers no callbacks of its own" do
        source = Rails.root.join("app/controllers/concerns/default_no_store.rb").read
        code = source.lines.reject { |line| line.lstrip.start_with?("#") }.join

        assert_no_match(/included\s+do|_action\b|on_load|class_eval|respond_to\?/, code)
      end
    end
  end
end
