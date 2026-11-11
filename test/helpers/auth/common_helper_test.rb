# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class Auth::CommonHelperTest < ActionView::TestCase
  setup do
    extend Auth::CommonHelper
  end

  test "sign up birthdate order follows date format preference" do
    assert_equal %w(year month day), sign_up_birthdate_part_order("iso")
    assert_equal %w(month day year), sign_up_birthdate_part_order("us")
    assert_equal %w(day month year), sign_up_birthdate_part_order("uk")
  end

  test "get_language returns ja" do
    assert_equal "ja", get_language
  end
end
