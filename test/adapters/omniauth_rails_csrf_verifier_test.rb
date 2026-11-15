# typed: false
# frozen_string_literal: true

require "test_helper"

class OmniauthRailsCsrfVerifierTest < ActiveSupport::TestCase
  setup do
    @previous_forgery_protection = ApplicationController.allow_forgery_protection
    ApplicationController.allow_forgery_protection = true
  end

  teardown do
    ApplicationController.allow_forgery_protection = @previous_forgery_protection
  end

  test "controller configuration is shared with the OmniAuth verifier" do
    assert_same ApplicationController.config, OmniauthRailsCsrfVerifier.config
  end

  test "Rails fallback instrumentation sees request action metadata" do
    assert_equal "request", OmniauthRailsCsrfVerifier.new.action_name
  end

  test "safe reads pass and an unverified unsafe callback raises the Rails cross-origin exception" do
    verifier = OmniauthRailsCsrfVerifier.new
    request = ActionController::TestRequest.create(ApplicationController)
    get_env = request.env.dup
    get_env["REQUEST_METHOD"] = "GET"
    post_env = request.env.dup
    post_env["REQUEST_METHOD"] = "POST"

    assert_nil verifier._call(get_env)
    assert_raises(ActionController::InvalidCrossOriginRequest) { verifier._call(post_env) }
  end
end
