# typed: false
# frozen_string_literal: true

require "test_helper"
# require "helpers/global_test_support"

class ApplicationHelperTest < ActionView::TestCase
  include ActiveSupport::Testing::TimeHelpers

  fixtures :client_banners, :operator_banners, :clients, :client_statuses, :operators,
           :operator_statuses

  setup do
    @helper_context = view
    @helper_context.extend(ApplicationHelper)
    define_singleton_method(:theme_cookie_value) { |value = nil| @helper_context.theme_cookie_value(value) }
    define_singleton_method(:theme_html_class) { |value = nil| @helper_context.theme_html_class(value) }
    define_singleton_method(:current_banner_for) { |**kwargs| @helper_context.current_banner_for(**kwargs) }
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

  test "current_banner_for returns current banner for each surface" do
    travel_to Time.zone.parse("2026-03-18 00:00:00 UTC") do
      assert_equal client_banners(:newer_current_user_banner), current_banner_for(tld: :app, region: :jp, domain: :news)
      assert_equal operator_banners(:current_staff_banner), current_banner_for(tld: :org, region: :jp, domain: :news)
    end
  end

  test "current_banner_for uses the writing connection" do
    travel_to Time.zone.parse("2026-03-18 00:00:00 UTC") do
      roles = []

      AppZenithRecord.stub(
        :connected_to, ->(role:, &block) do
                         roles << role
                         block.call
                       end,
      ) do
        assert_equal client_banners(:newer_current_user_banner),
                     current_banner_for(tld: :app, region: :jp, domain: :news)
      end

      assert_equal [:writing], roles
    end
  end

  test "current_banner_for returns nil when the connection is unavailable" do
    travel_to Time.zone.parse("2026-03-18 00:00:00 UTC") do
      AppZenithRecord.stub(
        :connected_to,
        ->(*) {
          raise ActiveRecord::ConnectionNotEstablished
        },
      ) do
        assert_nil current_banner_for(tld: :app, region: :jp, domain: :news)
      end
    end
  end

  test "current_banner_for normalizes a :global region to :ww for sign and acme domains" do
    travel_to Time.zone.parse("2026-03-18 00:00:00 UTC") do
      assert_equal client_banners(:newer_current_user_banner),
                   current_banner_for(tld: :app, region: :global, domain: :sign)
      assert_equal client_banners(:newer_current_user_banner),
                   current_banner_for(tld: :app, region: :global, domain: :acme)
    end
  end

  private
end
