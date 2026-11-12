# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class ActionPolicyUsageTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  OP_AUTHORITY_CONTROLLERS = [Visa::App::AuthorityController, Visa::Org::AuthorityController].freeze

  MUTATION_ACTIONS = %w(create update destroy).freeze

  PRIVATE_MUTATION_AUTHORIZATION_EXCEPTIONS = [].freeze

  test "OP authorities enforce the explicit crypto boundary instead of a retired actor policy" do
    OP_AUTHORITY_CONTROLLERS.each do |controller|
      assert_includes controller.ancestors, OpBrowserSessionRequest
      assert_not controller.method_defined?(:current_policy_user)
      assert_not controller.private_method_defined?(:current_policy_user)
      assert_equal :deny_all, controller.const_get(:AUTHENTICATION_MODE)
      filters =
        controller._process_action_callbacks.filter_map do |callback|
          callback.filter if callback.kind == :before
        end

      assert_includes filters, :enforce_op_boundary_mode!
    end
  end

  test "application code does not use Pundit" do
    offenders = matching_lines(/\bPundit\b|\bpundit\b/, paths_under("app", "lib", "config"))

    assert_empty offenders, "Use Action Policy only. Remove Pundit references:\n#{offenders.join("\n")}"
  end

  test "application code does not use authorization bypass helpers" do
    offenders = matching_lines(/\bskip_authorization\b|\bskip_policy_scope\b/, paths_under("app", "lib", "config"))

    assert_empty offenders, "Authorization bypass helpers are forbidden:\n#{offenders.join("\n")}"
  end

  test "private mutation controller actions explicitly call authorize or document an exception" do
    offenders = private_mutation_actions_without_authorize - PRIVATE_MUTATION_AUTHORIZATION_EXCEPTIONS

    assert_empty offenders,
                 "Private mutation actions must call authorize! or be allowlisted with a " \
                 "reason:\n#{offenders.join("\n")}"
  end

  private

  def paths_under(*roots)
    roots.flat_map { |root| Rails.root.glob("#{root}/**/*") }.select { |path| File.file?(path) }
  end

  def matching_lines(pattern, paths)
    paths.flat_map do |path|
      relative_path = path.relative_path_from(Rails.root).to_s
      content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)

      content.each_line.with_index(1).filter_map do |line, line_number|
        "#{relative_path}:#{line_number}: #{line.strip}" if line.match?(pattern)
      end
    end
  end

  def private_mutation_actions_without_authorize
    paths_under("app/controllers").filter_map do |path|
      relative_path = path.relative_path_from(Rails.root).to_s
      content = File.binread(path).encode("UTF-8", invalid: :replace, undef: :replace)
      next unless private_controller_source?(content)

      MUTATION_ACTIONS.filter_map do |action|
        body = action_body(content, action)
        next if body.blank? || body.include?("authorize!")

        "#{relative_path}##{action}"
      end
    end.flatten.sort
  end

  def private_controller_source?(content)
    content.include?("declare_authentication_mode! :private") ||
      content.include?("AUTHENTICATION_MODE = :private")
  end

  def action_body(content, action)
    action_re = Regexp.escape(action)
    match = content.match(
      /^\s*def #{action_re}\b(?<body>[\s\S]*?)(?=^\s*def\s|^\s*private\b|^\s*protected\b|^\s*end\s*$)/,
    )
    match&.named_captures&.fetch("body")
  end
end
