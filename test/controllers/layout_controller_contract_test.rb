# typed: false
# frozen_string_literal: true

require "test_helper"

class LayoutControllerContractTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  CONTROLLERS = {
    "app/controllers/auth/app/application_controller.rb" => ["Auth::App::ApplicationController",
                                                             "auth/app/application",],
    "app/controllers/auth/org/application_controller.rb" => ["Auth::Org::ApplicationController",
                                                             "auth/org/application",],
    "app/controllers/visa/app/authority_controller.rb" => ["Visa::App::AuthorityController",
                                                           "visa/app/application",],
    "app/controllers/visa/org/authority_controller.rb" => ["Visa::Org::AuthorityController",
                                                           "visa/org/application",],
  }.freeze

  test "Auth application and Visa authority controllers declare literal layouts" do
    CONTROLLERS.each do |path, (controller_name, layout_name)|
      contents = Rails.root.join(path).read
      controller = controller_name.safe_constantize

      assert_predicate controller, :present?
      assert_equal layout_name, controller._layout
      assert_includes contents, %(layout "#{layout_name}"), "missing literal layout declaration in #{path}"
      assert_no_match(
        /\blayout\s*(?:->|do|proc|lambda|method)/, contents,
        "layout declaration in #{path} must stay literal",
      )
    end
  end

  test "Visa owns the App and Org authority layouts" do
    assert_equal "visa/app/application", Visa::App::AuthorityController._layout
    assert_equal "visa/org/application", Visa::Org::AuthorityController._layout
    assert_predicate Rails.root.join("app/views/layouts/visa/app/application.html.erb"), :exist?
    assert_predicate Rails.root.join("app/views/layouts/visa/org/application.html.erb"), :exist?
  end
end
