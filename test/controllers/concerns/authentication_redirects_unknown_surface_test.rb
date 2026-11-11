# typed: false
# frozen_string_literal: true

require "test_helper"

# A controller outside the Auth and Visa namespaces has no sign-in surface. Asking it
# for a sign-in destination must fail, never resolve to a root path or to a
# guessed "/dashboard" or "/welcome" (no-silent-fallback).
class AuthenticationRedirectsUnknownSurfaceTest < ActionController::TestCase
  self.fixture_table_names = []

  # Defined inside this test class, so its name does not begin with a surface namespace.
  class SignInCompletionsController < ApplicationController
    include AuthenticationRedirects

    public

    def dashboard
      redirect_to(after_dashboard_path)
    end

    def welcome
      redirect_to(sign_in_welcome_path)
    end

    def oidc_authentication_ceremony? = false
  end

  tests SignInCompletionsController

  test "missing relying-party dashboard return fails explicitly" do
    with_surface_probe_routes do
      error = assert_raises(ActionController::BadRequest) { get(:dashboard) }

      assert_equal "No relying-party dashboard return is available", error.message
    end

    assert_nil response.location
  end

  test "missing relying-party welcome return fails explicitly" do
    with_surface_probe_routes do
      error = assert_raises(ActionController::BadRequest) { get(:welcome) }

      assert_equal "No relying-party welcome return is available", error.message
    end

    assert_nil response.location
  end

  private

  def with_surface_probe_routes(&)
    with_routing do |set|
      set.draw do
        get("/probe/dashboard", to: "authentication_redirects_unknown_surface_test/sign_in_completions#dashboard")
        get("/probe/welcome", to: "authentication_redirects_unknown_surface_test/sign_in_completions#welcome")
      end
      yield
    end
  end
end
