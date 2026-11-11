# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class IdentityAuthorityInversionGuardTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "sign routes do not expose oidc provider endpoints" do
    source = file_content("config/routes/auth.rb")

    assert_source_excludes source, "resource :openid_configuration"
    assert_source_excludes source, "namespace :oauth"
    assert_source_excludes source, "namespace :oidc"
    assert_source_excludes source, "resource :refresh"
    assert_source_excludes source, "resource :up, only: :show"
    assert_source_excludes source, "resource :in, only: :show"
    assert_source_excludes source, "resource :out, only: %i(new edit create destroy)"
  end

  test "route sources use noun lifecycle resources for edge and preference routes" do
    auth_routes = file_content("config/routes/auth.rb")
    visa_routes = Rails.root.join("config/routes/visa.rb").read.gsub(/\s+/, " ").strip

    assert_not_predicate Rails.root.join("config/routes/base.rb"), :exist?

    assert_source_excludes auth_routes, 'path: "check", controller: :checks'
    # Root-cookie transport and token lifecycle belong to Visa as the OP authority.
    assert_includes visa_routes, 'resource :status, only: :show, path: "check", controller: :checks'
    assert_includes visa_routes, "resource :dbsc, only: :create"
    assert_includes visa_routes, "resource :refresh, only: :create"
    assert_source_includes auth_routes,
                           'resource :registration, only: :show, path: "up", ' \
                           "controller: :ups, as: :up"
    assert_source_includes auth_routes,
                           'resource :session, only: :show, path: "in", ' \
                           "controller: :ins, as: :in"
    assert_equal 2, auth_routes.scan("resource :registration, only: :create, controller: :registrations").length
    assert_equal 2, auth_routes.scan("resource :session, only: :create, controller: :sessions").length
    assert_source_excludes auth_routes, 'path: "out"'
    assert_source_excludes auth_routes, "resource :termination"
    assert_includes visa_routes, "resource(:logout, only: %i(show create), controller: :logouts)"
  end

  test "Auth session refresh calls the Auth-owned issuer" do
    auth_base = file_content("app/controllers/concerns/authentication_base.rb")
    issuer = file_content("app/operations/auth_refresh_token_issuer.rb")

    assert_source_includes auth_base, "AuthRefreshTokenIssuer.call(refresh_token: refresh_plain)"
    assert_source_includes issuer, "class AuthRefreshTokenIssuer"
  end

  test "unknown social signup compatibility is explicit" do
    concern = file_content("app/controllers/concerns/social_auth.rb")

    assert_source_includes concern, "auth_social_admission_binding!"
    assert_source_includes concern, "ExternalAuthenticationLoginUseCase.call"
    assert_source_includes concern, "stage_social_link_completion!"
    link = file_content("app/controllers/auth/app/social/link_completions_controller.rb")

    assert_source_includes link, "ExternalAuthenticationLinkUseCase.call"
    assert_source_includes link, "require_recent_step_up!"
    assert_source_includes link, "token.with_lock"
    assert_source_includes concern, "resolve_social_auth_callback_result"
    assert_source_includes concern, "sign_up_entry: current_social_auth_entry == \"sign_up\""
  end

  test "sign email signup checkpoint uses the shared finalize boundary" do
    controller = file_content("app/controllers/auth/app/sign/up/check/email/birthdates_controller.rb")

    assert_source_includes controller, "sign_up_family = \"email\""
    assert_no_match(/email_signup_completion/, controller)
  end

  test "social confirmation step includes turnstile before durable signup completion" do
    # The confirmation step is an Inertia page now: the component draws the widget and the
    # confirmation field, and the controller is what binds the visible challenge to this ceremony.
    form = file_content("src/features/auth/signup/SocialSignUpConfirmation.tsx")

    assert_source_includes form, "<TurnstileWidget {...turnstile} />"
    assert_source_includes form, "confirm_new_social_identity"

    %w(google apple).each do |provider|
      controller = file_content(
        "app/controllers/auth/app/sign/up/check/#{provider}/confirmations_controller.rb",
      )

      assert_source_includes controller, "turnstile: turnstile_visible_props("
      assert_source_includes controller, "confirm_new_social_identity"
    end
  end

  private

  def assert_files_include(paths, expected)
    paths.each do |path|
      assert_source_includes file_content(path), expected, path
    end
  end

  def file_content(path)
    Rails.root.join(path).read
  end

  # These guards assert that a route is *declared*, not how the declaration happens to be
  # wrapped. Matching raw source made them fail whenever a formatter moved an argument to
  # the next line, which says nothing about the invariant being guarded. Collapse runs of
  # whitespace on both sides so the comparison is about the declaration itself.
  def normalize_source(text)
    text.gsub(/\s+/, " ").strip
  end

  def assert_source_includes(source, snippet, message = nil)
    assert_includes normalize_source(source), normalize_source(snippet), message
  end

  def assert_source_excludes(source, snippet, message = nil)
    assert_not_includes normalize_source(source), normalize_source(snippet), message
  end
end
