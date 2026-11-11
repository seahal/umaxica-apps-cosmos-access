# typed: false
# frozen_string_literal: true

require "test_helper"

class AuthVisaAuthorityBoundaryTest < ActiveSupport::TestCase
  AUTH_APPLICATION_CONTROLLERS = [
    Auth::App::ApplicationController,
    Auth::Org::ApplicationController,
  ].freeze

  VISA_AUTHORITY_CONTROLLERS = [
    Visa::App::AuthorityController,
    Visa::Org::AuthorityController,
  ].freeze

  test "Auth application controllers do not inherit browser RP lifecycle" do
    AUTH_APPLICATION_CONTROLLERS.each do |controller|
      assert_not controller.private_method_defined?(:oidc_client_id), controller.name
    end
  end

  test "Visa Authority controllers own the root session lifecycle independently" do
    VISA_AUTHORITY_CONTROLLERS.each do |controller|
      assert_equal ApplicationController, controller.superclass, controller.name
      assert_includes controller.ancestors, AuthenticationBase, controller.name
      assert_includes controller.ancestors, FqdnAvailabilityGate, controller.name
      assert_includes controller.ancestors, DefaultNoStore, controller.name
      assert_includes controller.ancestors, ActorSupport, controller.name
    end

    assert_equal "visa/app/application", Visa::App::AuthorityController._layout
    assert_equal "visa/org/application", Visa::Org::AuthorityController._layout
  end

  test "Visa Authority callbacks preserve security gates without the Org second-passkey gate" do
    callback_filters =
      lambda do |controller|
        controller._process_action_callbacks.map do |callback|
          callback.filter.is_a?(Proc) ? :framework_callback : callback.filter
        end
      end

    [Visa::App::AuthorityController, Visa::Org::AuthorityController].each do |controller|
      callbacks = callback_filters.call(controller)

      assert_includes callbacks, :require_authenticity_token_for_unsafe_request!, controller.name
      assert_includes callbacks, :apply_default_no_store, controller.name
      assert_includes callbacks, :enforce_verification_if_required, controller.name
      assert_includes callbacks, :enforce_access_policy!, controller.name
    end

    assert_not_includes callback_filters.call(Visa::Org::AuthorityController), :enforce_second_passkey_gate!
  end

  test "Auth has no sign-out relay routes" do
    ["auth.app.localhost", "auth.org.localhost"].each do |host|
      %i(get post delete).each do |method|
        assert_raises(ActionController::RoutingError) do
          Rails.application.routes.recognize_path("http://#{host}/sign/out", method: method)
        end
      end
    end
  end
end
