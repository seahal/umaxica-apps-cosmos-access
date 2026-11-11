# frozen_string_literal: true

require "test_helper"

class PreferenceBrowserControlsRegistryTest < ActiveSupport::TestCase
  API_THEME = "/api/v0/preferences/theme"
  API_COOKIE = "/api/v0/preferences/cookie"

  test "Auth declares same-origin theme and cookie endpoints on app and org" do
    %w(app org).each do |surface|
      controls = PreferenceBrowserControlsRegistry.fetch(family: "auth", surface: surface)

      assert_equal API_THEME, controls.theme_endpoint_path, "auth/#{surface} theme"
      assert_equal API_COOKIE, controls.cookie_endpoint_path, "auth/#{surface} cookie"
    end
  end

  test "Visa pages keep preference display read-only" do
    %w(app org).each do |surface|
      controls = PreferenceBrowserControlsRegistry.fetch(family: "visa", surface: surface)

      assert_nil controls.theme_endpoint_path, "visa/#{surface} theme"
      assert_nil controls.cookie_endpoint_path, "visa/#{surface} cookie"
    end
  end

  test "Auth and Visa differ for the same surface" do
    auth = PreferenceBrowserControlsRegistry.fetch(family: "auth", surface: "app")
    visa = PreferenceBrowserControlsRegistry.fetch(family: "visa", surface: "app")

    assert_not_equal auth, visa
  end

  test "family and surface symbols resolve like strings" do
    assert_equal PreferenceBrowserControlsRegistry.fetch(family: "auth", surface: "org"),
                 PreferenceBrowserControlsRegistry.fetch(family: :auth, surface: :org)
  end

  test "every declared endpoint path is origin-relative" do
    PreferenceBrowserControlsRegistry::MATRIX.each_value do |surfaces|
      surfaces.each_value do |controls|
        [controls.theme_endpoint_path, controls.cookie_endpoint_path].compact.each do |path|
          assert_match %r{\A/(?!/)}, path
        end
      end
    end
  end

  test "an unknown family raises" do
    error = assert_raises(KeyError) { PreferenceBrowserControlsRegistry.fetch(family: "unknown", surface: "app") }

    assert_match "unknown", error.message
  end

  test "a family/surface pair that does not exist raises" do
    [%w(auth com), %w(auth dev), %w(visa com), %w(visa dev)].each do |family, surface|
      assert_raises(KeyError, "#{family}/#{surface}") do
        PreferenceBrowserControlsRegistry.fetch(family: family, surface: surface)
      end
    end
  end

  test "nil and empty family or surface raise" do
    assert_raises(KeyError) { PreferenceBrowserControlsRegistry.fetch(family: nil, surface: "app") }
    assert_raises(KeyError) { PreferenceBrowserControlsRegistry.fetch(family: "", surface: "app") }
    assert_raises(KeyError) { PreferenceBrowserControlsRegistry.fetch(family: "auth", surface: nil) }
    assert_raises(KeyError) { PreferenceBrowserControlsRegistry.fetch(family: "auth", surface: "") }
  end
end
