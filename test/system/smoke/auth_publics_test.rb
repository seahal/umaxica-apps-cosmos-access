# frozen_string_literal: true

require "application_system_test_case"

class AuthPublicsTest < ApplicationSystemTestCase
  test "Auth liveness renders in Chromium" do
    visit "/health/liveness"

    assert_text "ok", exact: true
    assert_current_path "/health/liveness"
  end

  test "Auth root remains retired after browser navigation and back" do
    visit "/"

    assert_text '{"error":"unknown_host"}'

    visit "/health/liveness"

    assert_text "ok", exact: true

    page.go_back

    assert_current_path "/"
    assert_text '{"error":"unknown_host"}'
  end
end
