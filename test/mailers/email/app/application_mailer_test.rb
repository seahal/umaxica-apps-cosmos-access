# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Email::App::ApplicationMailerTest < ActionMailer::TestCase
  test "does not expose Base promotional unsubscribe helpers" do
    methods = Email::App::ApplicationMailer.ancestors.flat_map(&:instance_methods)

    assert_not_includes methods, :set_promotional_unsubscribe_headers
    assert_not_includes methods, :promotional_unsubscribe_url
  end
end
