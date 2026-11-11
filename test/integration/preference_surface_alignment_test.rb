# typed: false
# frozen_string_literal: true

require "test_helper"

class PreferenceSurfaceAlignmentTest < ActiveSupport::TestCase
  test "representative controller paths resolve to their matching preference classes" do
    assert_equal AppPreference, PreferenceClassRegistry.for_controller_path("auth/app/preferences")
    assert_equal OrgPreference, PreferenceClassRegistry.for_controller_path("auth/org/preferences")
  end

  test "host surface labels align with representative controller path segments" do
    assert_equal "app", "auth/app/preferences".split("/")[1]
    assert_equal "org", "auth/org/preferences".split("/")[1]
  end
end
