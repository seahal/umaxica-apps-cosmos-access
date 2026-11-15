# typed: false
# frozen_string_literal: true

require "test_helper"

class BaseAdmissionBrowserBindingTest < ActionDispatch::IntegrationTest
  # The test controller exercises the concern through HTTP actions without restoring retired Auth routes.
  class HarnessController < ActionController::Base # rubocop:disable Rails/ApplicationController
    include BaseAdmissionBrowserBinding

    TestTransaction = Data.define(:surface)

    def self.base_admission_surface_name = "app"

    def issue
      render plain: base_admission_browser_nonce_for_request!
    rescue BaseAuthAdmissionCoordinator::Denied
      head :unprocessable_entity
    end

    def read_nonce
      render plain: base_admission_browser_nonce.to_s
    end

    def require_nonce
      render plain: require_base_admission_browser_nonce!
    rescue BaseAuthAdmissionCoordinator::Denied
      head :unprocessable_entity
    end

    def digest
      render plain: base_admission_browser_digest(params.fetch(:entry_ref))
    rescue BaseAuthAdmissionCoordinator::Denied
      head :unprocessable_entity
    end

    def continuation
      apply_base_browser_continuation_headers!
      head :no_content
    end

    def validate_result
      validate_base_result_browser_binding!(TestTransaction.new("app"))
      head :ok
    rescue BaseAuthAdmissionCoordinator::Denied
      head :unprocessable_entity
    end

    def registration_restart
      base_registration_restart_binding!(scope: "settings_email", method: "passkey")
      head :ok
    rescue BaseAuthAdmissionCoordinator::Denied
      head :unprocessable_entity
    end

    private

    def current_session_token = nil
  end

  test "a new admission rotates its marker and a restart requires the existing marker" do
    with_harness_route do
      post "/binding/issue"

      assert_response :success
      nonce = response.body

      assert_match(/\A[A-Za-z0-9_-]{43}\z/, nonce)
      get "/binding/require_nonce"

      assert_equal nonce, response.body

      post "/binding/issue", params: { restart_of: SecureRandom.uuid }

      assert_response :success
      assert_equal nonce, response.body
      get "/binding/nonce"

      assert_equal nonce, response.body
    end
  end

  test "a missing restart marker is refused without silently creating a new marker" do
    with_harness_route do
      get "/binding/require_nonce"

      assert_response :unprocessable_entity
      post "/binding/issue", params: { restart_of: SecureRandom.uuid }

      assert_response :unprocessable_entity
      get "/binding/nonce"

      assert_equal "", response.body
    end
  end

  test "the digest uses the browser marker and continuation responses deny caching and framing" do
    with_harness_route do
      post "/binding/issue"
      nonce = response.body
      entry_ref = SecureRandom.uuid
      expected = AuthAdmissionBinding.browser_digest(surface: "app", entry_ref: entry_ref, nonce: nonce)
      get "/binding/digest", params: { entry_ref: entry_ref }

      assert_equal expected, response.body
      assert_not_equal nonce, response.body

      get "/binding/continuation"

      assert_equal "private, no-store", response.headers["Cache-Control"]
      assert_equal "no-referrer", response.headers["Referrer-Policy"]
      assert_includes response.headers["Content-Security-Policy"], "frame-ancestors 'none'"
    end
  end

  test "result validation and registration restart reject missing browser proof" do
    with_harness_route do
      post "/binding/validate_result"

      assert_response :unprocessable_entity
      post "/binding/registration_restart", params: { restart_of: SecureRandom.uuid }

      assert_response :unprocessable_entity
      post "/binding/registration_restart"

      assert_response :success
    end
  end

  private

  def with_harness_route
    with_routing do |set|
      set.draw do
        post("/binding/issue", to: "base_admission_browser_binding_test/harness#issue")
        get("/binding/nonce", to: "base_admission_browser_binding_test/harness#read_nonce")
        get("/binding/digest", to: "base_admission_browser_binding_test/harness#digest")
        get("/binding/continuation", to: "base_admission_browser_binding_test/harness#continuation")
        post("/binding/validate_result", to: "base_admission_browser_binding_test/harness#validate_result")
        post(
          "/binding/registration_restart",
          to: "base_admission_browser_binding_test/harness#registration_restart",
        )
        get("/binding/require_nonce", to: "base_admission_browser_binding_test/harness#require_nonce")
      end
      yield
    end
  end
end
