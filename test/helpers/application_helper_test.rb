# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class ApplicationHelperTest < ActionView::TestCase
  include ActiveSupport::Testing::TimeHelpers

  setup do
    @helper_context = view
    @helper_context.extend(ApplicationHelper)
    define_singleton_method(:theme_cookie_value) { |value = nil| @helper_context.theme_cookie_value(value) }
    define_singleton_method(:theme_html_class) { |value = nil| @helper_context.theme_html_class(value) }
  end

  test "theme_cookie_value maps the Preference theme codes and names" do
    { "dr" => "dark",
      "dark" => "dark",
      "li" => "light",
      "light" => "light",
      "sy" => "system",
      "system" => "system", }.each do |value, expected|
      assert_equal expected, theme_cookie_value(value), value
    end
  end

  test "theme_cookie_value reads the request Actor display value" do
    Actor.install_context!(preferences: Actor::Preference.new(theme: "dr"))

    assert_equal "dark", theme_cookie_value
  ensure
    Actor.clear
  end

  test "theme_cookie_value uses system for a missing or unsupported value" do
    Actor.install_context!(preferences: Actor::Preference::NULL)

    assert_equal "system", theme_cookie_value
    assert_equal "system", theme_cookie_value("unknown")
  ensure
    Actor.clear
  end

  test "theme_html_class includes dark class only for dark Preference theme" do
    assert_equal "theme-dark dark", theme_html_class("dr")
    assert_equal "theme-light", theme_html_class("li")
    assert_equal "theme-system", theme_html_class("sy")
  end

  test "page_title sets content for with title" do
    view.extend(ApplicationHelper)
    view.content_for(:page_title, nil)

    view.page_title("Test Title")

    assert_equal "Test Title", view.content_for(:page_title)
  end

  test "page_title returns blank when no title set so the site title stands alone" do
    view.extend(ApplicationHelper)

    assert_predicate view.page_title, :blank?
  end
end
