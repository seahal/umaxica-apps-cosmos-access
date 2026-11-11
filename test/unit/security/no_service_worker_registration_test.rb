# frozen_string_literal: true

require "test_helper"

class NoServiceWorkerRegistrationTest < ActiveSupport::TestCase
  test "Access source does not register or route a service worker" do
    source_paths =
      %w(src app).flat_map do |directory|
        Rails.root.glob("#{directory}/**/*").select do |path|
          path.file? && path.extname.match?(/\A\.(?:erb|js|jsx|rb|ts|tsx)\z/)
        end
      end
    source = source_paths.map(&:read).join("\n")

    assert_no_match(/navigator\s*\.\s*serviceWorker\s*\.\s*register/i, source)

    route_paths = [Rails.root.join("config/routes.rb"), *Rails.root.glob("config/routes/**/*.rb")]
    routes = route_paths.map(&:read).join("\n")

    assert_no_match(/service[_-]?worker/i, routes)
    assert_no_match(/\b(?:get|match|post|put|patch|delete)\s*\(?\s*["'][^"']+\.js(?:[?#][^"']*)?["']/i, routes)
  end
end
