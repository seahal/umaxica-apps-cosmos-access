# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class RedirectsNavigationTargetResolverTest < ActiveSupport::TestCase
  Routes =
    Struct.new(:calls) do
      def auth_app_sign_in_check_path(ri:) = "/sign/in/check?ri=#{ri}"

      def auth_app_sign_in_path(ri:) = "/sign/in?ri=#{ri}"

    end

  test "resolves registered navigation keys" do
    assert_equal "/sign/in/check?ri=jp", resolve(:checkpoint).value
    assert_equal "/sign/in?ri=jp", resolve(:selector).value
  end

  test "rejects unknown raw url and raw path keys" do
    assert_not resolve(:missing).ok?
    assert_not resolve("https://evil.example").ok?
    assert_not resolve("/dashboard").ok?
  end

  test "enforces flow scope" do
    result = resolve(:selector, scope: :settings)

    assert_not result.ok?
    assert_equal "scope_denied", result.failure_reason
  end

  test "rejects navigation targets for retired surfaces" do
    %i(dashboard signed_out home settings_security).each do |key|
      result = resolve(key)

      assert_not result.ok?
      assert_equal "unknown_key", result.failure_reason
    end
  end

  test "does not resolve external urls from registry" do
    routes = Class.new do
      def auth_app_sign_in_path(**) = "https://evil.example"
    end.new
    result = RedirectsNavigationTargetResolver.call(
      :selector,
      routes: routes,
      params: { ri: "jp", surface: "app" },
      source: :test,
    )

    assert_not result.ok?
    assert_equal "invalid_registered_path", result.failure_reason
  end

  private

  def resolve(key, scope: nil, params: { ri: "jp", surface: "app" })
    RedirectsNavigationTargetResolver.call(
      key,
      routes: Routes.new,
      params: params,
      scope: scope,
      source: :test,
    )
  end
end
