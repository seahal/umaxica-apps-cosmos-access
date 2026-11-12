# typed: false
# frozen_string_literal: true

require "test_helper"

class LayoutMetaTagsTest < ActiveSupport::TestCase
  self.fixture_table_names = []

  LAYOUT_PATHS = {
    "Visa::App" => "app/views/layouts/visa/app/application.html.erb",
    "Visa::Org" => "app/views/layouts/visa/org/application.html.erb",
  }.freeze

  INERTIA_LAYOUT_PATHS = {
    "Visa::App::Inertia" => "app/views/layouts/visa/app/inertia.html.erb",
    "Visa::Org::Inertia" => "app/views/layouts/visa/org/inertia.html.erb",
  }.freeze

  test "all layouts include a charset meta tag" do
    LAYOUT_PATHS.merge(INERTIA_LAYOUT_PATHS).each do |name, path|
      content = Rails.root.join(path).read

      assert_includes content, '<meta charset="utf-8">', "Expected charset meta tag in #{name} layout (#{path})"
    end
  end

  test "all layouts include title tag" do
    LAYOUT_PATHS.merge(INERTIA_LAYOUT_PATHS).each do |name, path|
      content = Rails.root.join(path).read

      assert_match(
        /display_meta_tags|<title>/, content,
        "Expected title tag in #{name} layout (#{path})",
      )
    end
  end

  test "inertia layout includes lang and theme markers" do
    INERTIA_LAYOUT_PATHS.each_value do |path|
      content = Rails.root.join(path).read

      assert_includes content, 'lang="<%= I18n.locale %>"'
      assert_includes content, 'data-theme="<%= theme_cookie_value %>"'
      assert_includes content, 'class="<%= theme_html_class %>"'
      assert_includes content, "page_title(inertia_page&.dig(:props, :title))"
    end
  end
end
