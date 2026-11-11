# typed: false
# frozen_string_literal: true

require "test_helper"

# Pins the provider x surface allow matrix enforced by the /social/* middleware.
#
# The matrix is deny-by-default: a host that owns no auth surface classifies as
# :unknown and gets no provider at all. Rails Host Authorization may admit many
# hosts, but only Auth APP and Auth ORG may start or complete external sign-in.
class OmniauthSocialProviderHostMatrixTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  PROVIDERS = %w(google apple entra).freeze

  setup do
    @downstream_called = false
    @matrix = OmniAuthSocialProviderHostMatrix.new(
      ->(_env) {
        @downstream_called = true
        [200, {}, ["ok"]]
      },
    )
    @hosts = Rails.configuration.x.boot_config.fetch(:hosts)
  end

  test "the app auth host allows Google and Apple and denies Entra" do
    assert_allowed host: app_auth_host, provider: "google"
    assert_allowed host: app_auth_host, provider: "apple"
    assert_denied host: app_auth_host, provider: "entra"
  end

  test "the org auth host allows Entra and denies Google and Apple" do
    assert_allowed host: org_auth_host, provider: "entra"
    assert_denied host: org_auth_host, provider: "google"
    assert_denied host: org_auth_host, provider: "apple"
  end

  test "the org auth host allows the Entra paths and denies other providers' paths" do
    %w(/social/entra /social/entra/callback /social/entra/failure).each do |path|
      assert_allowed host: org_auth_host, path: path
    end

    assert_denied host: org_auth_host, path: "/social/google"
    assert_denied host: org_auth_host, path: "/social/apple/callback"
  end

  test "Visa hosts allow no external provider" do
    [@hosts.visa_service.host, @hosts.visa_staff.host].each do |host|
      PROVIDERS.each do |provider|
        assert_denied host: host, provider: provider
      end
    end
  end

  test "non-provider social paths remain app-surface only" do
    assert_allowed host: app_auth_host, path: "/social/authentication/completion"
    assert_denied host: org_auth_host, path: "/social/authentication/completion"
    assert_denied host: @hosts.visa_service.host, path: "/social/authentication/completion"
  end

  test "paths outside /social are not touched by the matrix" do
    assert_allowed host: @hosts.visa_service.host, path: "/settings"
  end

  private

  def app_auth_host = @hosts.auth_service.host

  def org_auth_host = @hosts.auth_staff.host

  def call(host:, path:)
    @downstream_called = false
    env = Rack::MockRequest.env_for("https://#{host}#{path}", method: "GET")
    @matrix.call(env)
  end

  def assert_allowed(host:, provider: nil, path: nil)
    path ||= "/social/#{provider}/callback"
    status, = call(host: host, path: path)

    assert_equal 200, status, "expected #{host}#{path} to be allowed"
    assert @downstream_called, "expected #{host}#{path} to reach the application"
  end

  def assert_denied(host:, provider: nil, path: nil)
    path ||= "/social/#{provider}/callback"
    status, = call(host: host, path: path)

    assert_equal 404, status, "expected #{host}#{path} to be denied"
    assert_not @downstream_called, "expected #{host}#{path} never to reach the application"
  end
end
