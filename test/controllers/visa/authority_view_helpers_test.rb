# frozen_string_literal: true

require "test_helper"

class VisaAuthorityViewHelpersTest < ActionDispatch::IntegrationTest
  self.fixture_table_names = []

  test "APP and ORG views receive their own admission surface" do
    {
      Visa::App::AuthorityController => "app",
      Visa::Org::AuthorityController => "org",
    }.each do |controller_class, surface|
      assert_equal surface, controller_class.base_admission_surface_name
    end
  end

  test "view helpers distinguish missing sessions from the current session" do
    {
      Visa::App::AuthorityController => "app-session-public-reference",
      Visa::Org::AuthorityController => "org-session-public-reference",
    }.each do |controller_class, session_public_id|
      anonymous_controller = build_controller(controller_class)

      assert_not anonymous_controller.view_context.logged_in?
      assert_nil anonymous_controller.view_context.current_session_public_id

      device_session = Struct.new(:public_id).new(session_public_id)
      root = Struct.new(:device_session).new(device_session)
      resolver_result = Struct.new(:root).new(root)
      authenticated_controller = build_controller(controller_class)

      OpBrowserSessionResolver.stub(:call, resolver_result) do
        assert_predicate authenticated_controller.view_context, :logged_in?
        assert_equal session_public_id, authenticated_controller.view_context.current_session_public_id
      end
    end
  end

  private

  def build_controller(controller_class)
    controller = controller_class.new
    controller.request = ActionDispatch::TestRequest.create
    controller
  end
end
