# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class ActionPolicyUsageTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  SURFACE_AUTHORIZATION_CONTEXTS = {
    Auth::App::ApplicationController => { actor: :current_actor, user: :current_policy_user },
    Auth::Org::ApplicationController => { actor: :current_actor, user: :current_policy_user },
    Visa::App::AuthorityController => { actor: :current_actor, user: :current_policy_user },
    Visa::Org::AuthorityController => { actor: :current_actor, user: :current_policy_user },
  }.freeze

  MUTATION_ACTIONS = %w(create update destroy).freeze

  PRIVATE_MUTATION_AUTHORIZATION_EXCEPTIONS = [
    # Sign/settings ceremony endpoints are protected by ceremony state, provider ownership,
    # WebAuthn/passkey challenge state, or recovery/removal sequence gates rather than a durable
    # domain record policy at the controller action boundary.
    "app/controllers/auth/app/settings/apples_controller.rb#create",
    "app/controllers/auth/app/settings/apples_controller.rb#destroy",
    "app/controllers/auth/app/settings/googles_controller.rb#create",
    "app/controllers/auth/app/settings/googles_controller.rb#destroy",

    # Sign-in verification and cancellation ceremony endpoints are guarded by active flow,
    # checkpoint, and verification state rather than standalone mutable resource records.
    "app/controllers/auth/app/sign/in/checks_controller.rb#destroy",
    "app/controllers/auth/app/sign/in/checks_controller.rb#update",
    "app/controllers/auth/app/verification/emails_controller.rb#create",
    "app/controllers/auth/app/verification/emails_controller.rb#update",
    # Scoped verification endpoints authorize the admitted actor through their ceremony context;
    # the mutation applies to ceremony state rather than a standalone resource record.
    "app/controllers/auth/app/verification/passkeys_controller.rb#create",
    "app/controllers/auth/app/verification/redeliveries_controller.rb#create",
    "app/controllers/auth/app/verification/totps_controller.rb#create",
    "app/controllers/auth/org/sign/in/checks_controller.rb#destroy",
    "app/controllers/auth/org/sign/in/checks_controller.rb#update",

    # Identity registration and credential ceremony endpoints are sequence-bound controllers.
    # They create or complete pending identity artifacts scoped to the authenticated actor.

    # Session and revocation endpoints scope queries through the current actor's sessions or
    # support emergency revocation concern before mutating; keep these explicit until converted.

  ].freeze

  test "authenticated surface controllers use Action Policy with explicit actor context" do
    SURFACE_AUTHORIZATION_CONTEXTS.each do |controller_class, expected_context|
      assert_includes controller_class.ancestors,
                      ActionPolicy::Controller,
                      "#{controller_class.name} must include ActionPolicy::Controller"
      assert_equal(
        expected_context,
        controller_class.instance_variable_get(:@authorization_targets),
        "#{controller_class.name} must configure Action Policy actor and compatibility user contexts",
      )
    end
  end

  test "authenticated surface controllers run access policy before actions" do
    SURFACE_AUTHORIZATION_CONTEXTS.each_key do |controller_class|
      before_filters =
        controller_class._process_action_callbacks.filter_map do |callback|
          callback.filter if callback.kind == :before
        end

      assert_includes before_filters,
                      :enforce_access_policy!,
                      "#{controller_class.name} must run access policy enforcement"
      assert(
        controller_class.const_defined?(:AUTHENTICATION_MODE, false) ||
        controller_class.local_authentication_mode_rules.present?,
        "#{controller_class.name} must declare an authentication mode",
      )
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
