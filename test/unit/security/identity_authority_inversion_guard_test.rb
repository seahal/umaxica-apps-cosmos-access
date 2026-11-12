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
                           'controller: "/auth/app/unavailable_ceremonies", as: :up'
    assert_source_includes auth_routes,
                           'resource :session, only: :show, path: "in", ' \
                           'controller: "/auth/app/unavailable_ceremonies", as: :in'
    assert_equal 2,
                 auth_routes.scan(
                   "resource :registration, only: :create, " \
                   'controller: "/auth/app/unavailable_ceremonies"',
                 ).length
    assert_equal 2,
                 auth_routes.scan(
                   "resource :session, only: :create, " \
                   'controller: "/auth/app/unavailable_ceremonies"',
                 ).length
    assert_source_excludes auth_routes, 'path: "out"'
    assert_source_excludes auth_routes, "resource :termination"
    assert_includes visa_routes, "resource(:logout, only: %i(show create), controller: :logouts)"
  end

  test "browser root refresh uses the explicitly typed Auth issuer independently of RP refresh" do
    metadata = file_content("app/controllers/concerns/authentication_base.rb")
    boundary = file_content("app/controllers/concerns/op_browser_session_request.rb")
    issuer = file_content("app/operations/auth_refresh_token_issuer.rb")

    assert_source_excludes metadata, "refresh_access_token"
    assert_source_includes boundary,
                           "AuthRefreshTokenIssuer.call( refresh_token: secret, resource_type: resource_type,"
    assert_source_excludes boundary, "OidcRefreshTokenIssuer.call"
    assert_source_includes issuer, "class AuthRefreshTokenIssuer"
    assert_source_includes issuer, "def self.call(refresh_token:, resource_type:,"
  end

  test "local account creation and credential callback controllers are retired" do
    %w(
      app/controllers/auth/app/social/link_completions_controller.rb
      app/controllers/auth/app/sign/up/check/email/birthdates_controller.rb
      app/controllers/auth/app/sign/up/check/google/confirmations_controller.rb
      app/controllers/auth/app/sign/up/check/apple/confirmations_controller.rb
    ).each do |path|
      assert_not_predicate Rails.root.join(path), :exist?
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
