# frozen_string_literal: true

require "test_helper"

# Auth layouts derive preference control endpoints from the registry, so browser code uses the
# same origin's declared theme and cookie routes.
class ErbLayoutPreferenceControlsTest < ActiveSupport::TestCase
  LAYOUTS = [
    { family: "auth", surface: "app", controller: Auth::App::ApplicationController, host: "PUBLIC_AUTH_SERVICE_URL" },
    { family: "auth", surface: "org", controller: Auth::Org::ApplicationController, host: "PUBLIC_AUTH_STAFF_URL" },
  ].freeze

  test "Auth layouts expose their same-origin preference endpoints" do
    LAYOUTS.each do |layout|
      family = layout.fetch(:family)
      surface = layout.fetch(:surface)
      expected = PreferenceBrowserControlsRegistry.fetch(family: family, surface: surface)
      html = layout.fetch(:controller).renderer.new("HTTP_HOST" => ENV.fetch(layout.fetch(:host)))
        .render(inline: "", layout: "#{family}/#{surface}/application")
      document = Nokogiri::HTML(html)

      theme = document.at_css("[data-controller='theme']")
      banner = document.at_css("[data-controller='cookie-banner']")

      assert_equal expected.theme_endpoint_path, theme["data-theme-endpoint-url-value"], "#{family}/#{surface}"
      assert_equal expected.cookie_endpoint_path, banner["data-cookie-banner-endpoint-url-value"],
                   "#{family}/#{surface}"
    end
  end
end
