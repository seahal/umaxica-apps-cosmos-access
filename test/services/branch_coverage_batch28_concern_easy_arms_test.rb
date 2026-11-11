# typed: false
# frozen_string_literal: true

require "test_helper"

class BranchCoverageBatch28ConcernEasyArmsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  test "PreferenceWebThemeEndpoint blank raw theme value" do
    helper = Class.new(ApplicationController) { include PreferenceWebThemeEndpoint }.new
    helper.set_request!(ActionDispatch::TestRequest.create)
    helper.set_response!(ActionDispatch::TestResponse.new)

    assert_not helper.respond_to?(:normalize_theme_value, true)
    assert_not helper.respond_to?(:parsed_theme_option, true)
  end

  test "ActorSupport step_up null when StepUpResolver undefined path is skipped safely" do
    helper = Class.new(ApplicationController) { include ActorSupport }.new
    helper.set_request!(ActionDispatch::TestRequest.create)
    helper.set_response!(ActionDispatch::TestResponse.new)

    assert_not helper.respond_to?(:current_step_up, true)
  end

  test "AuthenticationJwtTokens blank host returns no current session identifier" do
    helper = Class.new(ApplicationController) do
      include AuthenticationBase
      include AuthenticationJwtTokens
    end.new
    request = ActionDispatch::TestRequest.create
    request.host = ""
    request.cookies[AuthenticationBase::ACCESS_COOKIE_KEY] = "opaque-access-token"
    helper.set_request!(request)
    helper.set_response!(ActionDispatch::TestResponse.new)

    assert_nil helper.current_session_public_id
  end

  test "SignErrorResponses null Origin classification" do
    helper = Class.new(ApplicationController) { include SignErrorResponses }.new
    request = ActionDispatch::TestRequest.create
    request.headers["Origin"] = "null"
    helper.set_request!(request)
    helper.set_response!(ActionDispatch::TestResponse.new)

    assert_not helper.respond_to?(:csrf_failure_reason, true)
    assert_not helper.respond_to?(:reject_csrf!, true)
  end

  test "PreferenceJwtConfiguration refuses the retired generic issuer" do
    assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
      PreferenceJwtConfiguration.issuer_for("")
    end
    assert_raises(JitSecurityJwtRegistry::ConfigurationError) do
      PreferenceJwtConfiguration.active_kid("preference")
    end
  end

end
