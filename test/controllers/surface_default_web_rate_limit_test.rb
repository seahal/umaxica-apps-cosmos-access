# typed: false
# frozen_string_literal: true

require "test_helper"

# Every surface declares its own default web limiter on its application
# controller, each with its own scope name, and the limiter is the only thing
# standing between an unauthenticated caller and unbounded traffic to that
# surface. A scope name that collides with another surface, a store that is not
# wired up, or a refusal handler that is never reached all look like a passing
# suite otherwise, because nothing else exercises the limiter itself.
#
# Each case sends the full quota and then one more request, so it also pins that
# the quota is not off by one in either direction.
class SurfaceDefaultWebRateLimitTest < ActionDispatch::IntegrationTest
  # Rate-limit counters are a NullStore by default in test so unrelated tests
  # cannot accumulate them; this file asserts real limiting behavior, so it
  # opts into a deterministic MemoryStore.
  rate_limit_counters!

  self.fixture_table_names = []

  DEFAULT_WEB_QUOTA = 300

  SURFACES = {
    "auth app" => ["PUBLIC_AUTH_SERVICE_URL", "/sign/in?ri=jp"],
    "auth org" => ["PUBLIC_AUTH_STAFF_URL", "/sign/in?ri=jp"],
    "visa app" => ["PUBLIC_VISA_SERVICE_URL", "/sign/in/limitation?ri=jp"],
    "visa org" => ["PUBLIC_VISA_STAFF_URL", "/sign/in/limitation?ri=jp"],
  }.freeze

  setup { Rails.configuration.x.rate_limit.fetch(:store).clear }
  teardown { Rails.configuration.x.rate_limit.fetch(:store).clear }

  SURFACES.each do |surface, (env_name, path)|
    test "#{surface} answers the request past its default web quota with a retry hint" do
      host! ENV.fetch(env_name)

      DEFAULT_WEB_QUOTA.times { get path }

      assert_not_equal 429, response.status,
                       "#{surface} refused a request inside its quota of #{DEFAULT_WEB_QUOTA}"

      get path

      assert_response :too_many_requests
      assert_equal "60", response.headers["Retry-After"]
    end
  end
end
